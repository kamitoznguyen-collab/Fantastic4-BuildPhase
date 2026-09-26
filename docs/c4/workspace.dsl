/*
 * C4 — Invoice Reconciliation Agent (P-143)
 *
 * Vẽ theo code thật ở repo P-143, nhánh feat/module-api, ngày 23/09/2026.
 * Xem: docker compose up -d rồi mở http://localhost:8080
 *
 * Mức 1  L1-Context       ai dùng hệ thống, hệ thống nói chuyện với ai
 * Mức 2  L2-Container     các khối triển khai
 * Mức 3  L3-Component     các module trong API và phụ thuộc giữa chúng
 *        L3-InvoiceFlow   một hóa đơn đi qua các module
 * Mức 4  L4-Reconciliation  lớp bên trong module reconciliation
 *        L4-ReconcileRun    một lần ReconcileInvoiceService.run
 *
 * Tag trạng thái: "Đang làm" = có interface hoặc khung, chưa chạy thật; "Chưa làm" = chưa có.
 * Không gắn tag = đã chạy được, có test.
 */
workspace "Invoice Reconciliation Agent" "Đối soát hóa đơn ↔ đơn đặt hàng ↔ phiếu nhập kho cho kế toán phải trả. Pilot: Xe X." {

    model {

        # ---- Người dùng và bên ngoài ------------------------------------------------------------

        ktv = person "Kế toán viên" "Tải hóa đơn lên, nhập đơn đặt hàng và phiếu nhập kho, xử lý chỗ lệch, duyệt cấp 1, xuất bút toán."
        ktt = person "Kế toán trưởng" "Duyệt cấp 2, cấu hình dung sai và ngưỡng duyệt, duyệt quy tắc nhà cung cấp, tra nhật ký kiểm toán."

        nhaCungCap = person "Nhà cung cấp" "Gửi hóa đơn điện tử (XML), PDF hoặc ảnh chụp qua email." {
            tags "External"
        }
        muaHang = person "Phòng mua hàng và kho" "Lập đơn đặt hàng, lập phiếu nhập kho; xuất ra file Excel." {
            tags "External"
        }

        phanMemKeToan = softwareSystem "Phần mềm kế toán" "MISA, Fast… Nhận file bút toán. Bản MVP không kết nối trực tiếp." {
            tags "External"
        }
        openai = softwareSystem "OpenAI" "LLM gpt-4o-mini (xếp trường, khớp tên hàng khó, viết giải thích) và embedding." {
            tags "External" "Chưa làm"
        }
        documentAi = softwareSystem "Google Document AI" "Đọc chữ từ PDF scan và ảnh, trả confidence từng token." {
            tags "External" "Chưa làm"
        }
        traCuuThue = softwareSystem "Tra cứu mã số thuế" "Mã số thuế còn hoạt động không. Giả lập trong bản MVP." {
            tags "External" "Chưa làm"
        }
        langsmith = softwareSystem "LangSmith" "Theo dõi từng lần gọi AI, đo chi phí mỗi hóa đơn." {
            tags "External" "Chưa làm"
        }

        # ---- Hệ thống ---------------------------------------------------------------------------

        p143 = softwareSystem "Hệ thống đối soát hóa đơn" "Đọc hóa đơn, tìm đơn đặt hàng và phiếu nhập kho, đối chiếu từng dòng, phân loại chỗ lệch, đề xuất cách xử lý, sinh bút toán. Không tự duyệt, không thanh toán." {

            web = container "Ứng dụng web" "Danh sách hóa đơn theo màu, màn so sánh 3 chiều, hàng đợi duyệt, cấu hình. Chưa có trong repo P-143." "HTML + JavaScript thuần, không cần build" {
                tags "Web Browser" "Chưa làm"
            }

            db = container "Cơ sở dữ liệu" "Dữ liệu nghiệp vụ mọi tổ chức (mọi bảng có org_id), nhật ký chỉ-thêm, cấu hình theo phiên bản. Migration SQL thuần có checksum." "PostgreSQL 18 (uuidv7) + pgvector" {
                tags "Database"
            }

            files = container "Kho file gốc" "File hóa đơn gốc, khóa org_id/sha256. STORAGE_BACKEND=local hoặc s3." "Ổ đĩa cục bộ / S3 / MinIO" {
                tags "Storage"
            }

            yaml = container "Cấu hình mặc định" "Dung sai, thuế suất theo ngày hiệu lực, chính sách duyệt, giới hạn, sơ đồ tài khoản. Đọc và kiểm tra lúc khởi động." "config/*.yaml" {
                tags "Storage"
            }

            api = container "API" "Modular monolith: toàn bộ nghiệp vụ, REST /api/v1, JWT, phân quyền. Pipeline xử lý nền chạy chung tiến trình." "Python 3.11, FastAPI, uvicorn, psycopg 3 async, SQL thuần" {

                # ---- Mức 3: module ----------------------------------------------------------

                group "Nền tảng" {
                    core = component "core" "DB pool, TenantUnitOfWork (một transaction cho một tổ chức), xác thực token, tiền Decimal, lỗi chuẩn, migrate." "src/core"
                    wiring = component "app.wiring" "Composition root: nơi duy nhất biết class cụ thể của mọi module; gắn repository và adapter chéo vào cùng một connection." "src/app/wiring.py"
                    pipeline = component "app.pipeline" "InProcessPipeline: UPLOADED → EXTRACTED → MATCHED → PENDING_L1. PIPELINE_MODE=background|inline|off. Sẽ thay bằng LangGraph + Postgres checkpointer." "asyncio" {
                        tags "Đang làm"
                    }
                }

                group "Quản trị" {
                    iam = component "iam" "Đăng nhập, access/refresh token, thu hồi, khóa tài khoản sau 5 lần sai. Bảng: orgs, users, sessions, revoked_access_tokens, login_attempts." "module"
                    rules = component "rules" "Cấu hình theo tổ chức (config_versions mới nhất đè lên YAML, có cache), danh mục mã ngoại lệ, đọc tiền bằng chữ. Bảng: config_versions." "module"
                    audit = component "audit" "Nhật ký cho mọi module, trong transaction của bên gọi; lọc và xuất cho kiểm toán. Bảng: audit_logs (chỉ INSERT, SELECT)." "module"
                }

                group "Danh mục" {
                    vendor = component "vendor" "Nhà cung cấp và quy tắc nhớ: tên hàng, quy đổi đơn vị, dung sai riêng. Bảng: vendors, vendor_rules." "module"
                    procurement = component "procurement" "Nhập đơn đặt hàng, phiếu nhập kho từ Excel/CSV; sổ số lượng đã hóa đơn từng dòng. Bảng: purchase_orders, po_lines, goods_receipts, grn_lines, po_line_invoicings." "module"
                    erp = component "erp" "Interface ErpConnector (Seed, ExcelCsv, sau này MISA). Bảng: sync_runs." "module" {
                        tags "Đang làm"
                    }
                }

                group "Tiếp nhận" {
                    invoice = component "invoice" "Tải lên, chống trùng sha256, máy trạng thái hóa đơn, ghi kết quả trích xuất, sửa trường. Bảng: files, upload_batches, invoices, invoice_lines, extraction_fields." "module"
                    extraction = component "extraction" "StrategyExtractionRouter: thử cách đọc rẻ nhất trước. Mới có XmlInvoiceExtractor (TT78); PDF, OCR chưa có." "module" {
                        tags "Đang làm"
                    }
                }

                group "Đối chiếu" {
                    reconciliation = component "reconciliation" "Tìm chứng từ, khớp dòng, kiểm toàn vẹn, dung sai, thuế; phân loại GREEN/YELLOW/RED; xử lý ngoại lệ; gán lại đơn đặt hàng. Không gọi LLM. Bảng: invoice_po_links, line_matches, discrepancies." "module"
                }

                group "Sau đối chiếu" {
                    approval = component "approval" "Duyệt, từ chối, trả lại; quyết định có cần cấp 2; tách biệt người duyệt; ghi số lượng đã hóa đơn khi duyệt xong. Bảng: approvals." "module"
                    ledger = component "ledger" "Soạn bút toán đề xuất, sửa tài khoản, xuất file; xuất là bước chốt APPROVED → POSTED. Bảng: journal_entries, journal_lines." "module"
                    reporting = component "reporting" "Danh sách công việc, tổng quan, điểm sẵn sàng tự động hóa của nhà cung cấp, chi phí, báo cáo đối soát. Không có bảng riêng." "module"
                }

                group "AI" {
                    gateway = component "gateway" "Cổng duy nhất ra dịch vụ AI: StructuredLlm, OcrEngine, Embedder, BudgetGuard; ghi chi phí, cache. Bảng: ai_calls, ai_cache." "module" {
                        tags "Đang làm"
                    }
                    semantic = component "semantic" "SemanticIndex: đánh chỉ mục và tìm theo vector (bậc 3 tìm chứng từ). Bảng: embeddings." "module" {
                        tags "Đang làm"
                    }
                }

                # ---- Mức 4: code bên trong reconciliation --------------------------------------

                group "reconciliation — code" {
                    cRouter = component "router" "Endpoint so sánh 3 chiều, ngoại lệ, resolve, relink-po." "handler/router.py" {
                        tags "Code"
                    }
                    cReview = component "DefaultReconciliationReview" "Xử lý ngoại lệ (chọn hành động, bắt buộc lý do khi khác đề xuất), gán lại đơn đặt hàng rồi chạy lại." "service/review.py" {
                        tags "Code"
                    }
                    cService = component "ReconcileInvoiceService" "Cài đặt interface ReconcileInvoice. Một transaction, số query cố định, mọi kiểm tra là hàm thuần, không LLM." "service/reconcile_invoice.py" {
                        tags "Code"
                    }
                    cRetrieval = component "TieredDocumentRetrieval" "Bậc 1: số đơn đặt hàng in trên hóa đơn. Bậc 2: mã số thuế + khoảng ngày, chấm điểm ứng viên. Bậc 3 (vector) chưa nối." "service/retrieval.py" {
                        tags "Code"
                    }
                    cLadder = component "LadderLineMatching" "Thang khớp dòng trong bộ nhớ: L0 mã hàng, L1 quy tắc nhớ, L2 chuỗi chuẩn hóa, L3 so chuỗi mờ; vùng mờ chuyển cho arbiter." "service/line_matching.py, domain/matching" {
                        tags "Code"
                    }
                    cArbiter = component "LineMatchArbiter" "Interface L4: chọn một trong các ứng viên hoặc từ chối. Câu trả lời ngoài danh sách bị bỏ." "domain/contracts/required.py" {
                        tags "Code" "Interface"
                    }
                    cInconclusive = component "InconclusiveArbiter" "Cài đặt hiện tại: luôn từ chối, dòng thành L5." "service/arbiter.py" {
                        tags "Code"
                    }
                    cLlmArbiter = component "LlmArbiter" "LLM chọn trong ứng viên, trả {po_line_id, confidence, reason}; ≥ 0.80 thì khớp kèm ITM-02." "chưa có" {
                        tags "Code" "Chưa làm"
                    }
                    cChecks = component "run_checks" "Hàm thuần trên ReconciliationContext: integrity (F3), tolerance (F6), tax (F7), lines (F5)." "domain/checks" {
                        tags "Code"
                    }
                    cClassify = component "classify" "BLOCK → RED, REVIEW → YELLOW, còn lại GREEN; không đủ confidence thì không được GREEN." "domain/classification.py" {
                        tags "Code"
                    }
                    cUow = component "PostgresReconciliationUnitOfWork" "Mở một transaction cho một tổ chức; repository của module và adapter sang module khác dùng chung connection." "repository/postgres/unit_of_work.py" {
                        tags "Code"
                    }
                    cResults = component "Postgres repositories" "PostgresDiscrepancyRepository, PostgresLineMatchRepository, liên kết đơn đặt hàng: ghi invoice_po_links, line_matches, discrepancies." "repository/postgres/results.py" {
                        tags "Code"
                    }
                    cInvoiceAcl = component "InvoiceSourceAdapter / InvoiceStatusSinkAdapter" "acl → invoice: nạp hóa đơn, dòng, confidence; chuyển EXTRACTED → MATCHED." "repository/acl/invoice.py" {
                        tags "Code"
                    }
                    cProcurementAcl = component "ProcurementSourceAdapter" "acl → procurement: tìm theo số, ứng viên mở, nạp đơn + dòng + phiếu nhập kho theo lô." "repository/acl/procurement.py" {
                        tags "Code"
                    }
                    cVendorAcl = component "VendorSourceAdapter" "acl → vendor: nhà cung cấp theo mã số thuế + quy tắc nhớ ACTIVE, nạp một lần mỗi lượt." "repository/acl/vendor.py" {
                        tags "Code"
                    }
                    cPolicyAcl = component "TenantPolicyResolver" "acl → rules: dung sai (nhà cung cấp → nhóm hàng → mặc định), thuế suất theo ngày, danh mục mã ngoại lệ." "repository/acl/rules.py" {
                        tags "Code"
                    }
                }
            }
        }

        # ---- Quan hệ: mức 1 --------------------------------------------------------------------

        nhaCungCap -> ktv "Gửi hóa đơn qua email"
        muaHang -> ktv "Gửi file Excel đơn đặt hàng, phiếu nhập kho"
        ktv -> phanMemKeToan "Nhập file bút toán"

        # ---- Quan hệ: mức 2 --------------------------------------------------------------------

        ktv -> web "Tải hóa đơn, nhập chứng từ, đối soát, duyệt cấp 1, xuất bút toán" "HTTPS"
        ktt -> web "Duyệt cấp 2, cấu hình, tra nhật ký" "HTTPS"

        # ---- Quan hệ: mức 3, web gọi module -----------------------------------------------------

        web -> iam "Đăng nhập, làm mới token" "REST + JSON" "REST"
        web -> invoice "Tải lên, xem, sửa trường, xử lý lại" "REST + JSON, Bearer JWT" "REST"
        web -> reconciliation "So sánh 3 chiều, xử lý ngoại lệ, gán lại đơn đặt hàng" "REST + JSON, Bearer JWT" "REST"
        web -> approval "Duyệt, từ chối, trả lại, hàng đợi" "REST + JSON, Bearer JWT" "REST"
        web -> ledger "Xem, sửa, xuất bút toán" "REST + JSON, Bearer JWT" "REST"
        web -> reporting "Danh sách, tổng quan, điểm sẵn sàng" "REST + JSON, Bearer JWT" "REST"
        web -> vendor "Nhà cung cấp, quy tắc nhớ" "REST + JSON, Bearer JWT" "REST"
        web -> procurement "Nhập Excel đơn đặt hàng, phiếu nhập kho" "REST + JSON, Bearer JWT" "REST"
        web -> rules "Xem, sửa cấu hình" "REST + JSON, Bearer JWT" "REST"
        web -> audit "Tra, xuất nhật ký" "REST + JSON, Bearer JWT" "REST"

        # ---- Quan hệ: mức 3, giữa các module (chỉ qua repository/acl) ---------------------------

        invoice -> extraction "Đọc file thành trường + confidence + bằng chứng"
        invoice -> rules "Giới hạn tải lên"
        invoice -> vendor "Nhận diện nhà cung cấp theo mã số thuế"
        invoice -> pipeline "Xếp hóa đơn vào hàng đợi"
        extraction -> gateway "OCR, LLM xếp trường" {
            tags "Chưa làm"
        }
        semantic -> gateway "Tạo embedding" {
            tags "Chưa làm"
        }
        procurement -> vendor "Tra / tạo nhà cung cấp khi nhập Excel"
        erp -> procurement "Ghi đơn đặt hàng, phiếu nhập kho đồng bộ về"
        erp -> vendor "Ghi nhà cung cấp đồng bộ về"
        pipeline -> invoice "Trích xuất; chuyển PENDING_L1"
        pipeline -> reconciliation "Đối chiếu"
        reconciliation -> invoice "Đọc hóa đơn; chuyển MATCHED"
        reconciliation -> procurement "Đọc đơn đặt hàng, phiếu nhập kho"
        reconciliation -> vendor "Đọc quy tắc nhớ"
        reconciliation -> rules "Dung sai, thuế suất, mã ngoại lệ"
        reconciliation -> pipeline "Đưa hóa đơn đã đối chiếu lại sang chờ duyệt"
        approval -> invoice "Chuyển PENDING_L2 / APPROVED / RETURNED / REJECTED"
        approval -> reconciliation "Đọc ngoại lệ đang mở, dòng đã khớp"
        approval -> procurement "Ghi số lượng đã hóa đơn"
        approval -> ledger "Soạn bút toán"
        approval -> rules "Chính sách duyệt"
        approval -> vendor "Nhà cung cấp mới?"
        ledger -> invoice "Đọc hóa đơn; chuyển POSTED"
        ledger -> reconciliation "Đọc dòng đã khớp"
        ledger -> procurement "Nhóm hàng, trung tâm chi phí"
        ledger -> rules "Sơ đồ tài khoản"
        ledger -> vendor "Mã nhà cung cấp"
        reporting -> invoice "Tìm kiếm, thống kê hóa đơn"
        reporting -> reconciliation "Thống kê ngoại lệ, khớp dòng"
        reporting -> approval "Lịch sử duyệt"
        reporting -> vendor "Ghi điểm sẵn sàng"

        # Nhật ký: mọi module có ghi dữ liệu đều ghi audit trong cùng transaction
        iam -> audit "Ghi nhật ký" "" "Audit"
        rules -> audit "Ghi nhật ký" "" "Audit"
        vendor -> audit "Ghi nhật ký" "" "Audit"
        invoice -> audit "Ghi nhật ký" "" "Audit"
        reconciliation -> audit "Ghi nhật ký" "" "Audit"
        approval -> audit "Ghi nhật ký" "" "Audit"
        ledger -> audit "Ghi nhật ký" "" "Audit"
        reporting -> audit "Ghi nhật ký" "" "Audit"

        # Lưu trữ: mỗi module chỉ đọc/ghi bảng của chính nó
        iam -> db "Đọc/ghi bảng của iam" "SQL" "SQL"
        audit -> db "Đọc/ghi bảng của audit" "SQL" "SQL"
        rules -> db "Đọc/ghi bảng của rules" "SQL" "SQL"
        vendor -> db "Đọc/ghi bảng của vendor" "SQL" "SQL"
        procurement -> db "Đọc/ghi bảng của procurement" "SQL" "SQL"
        erp -> db "Đọc/ghi bảng của erp" "SQL" "SQL"
        invoice -> db "Đọc/ghi bảng của invoice" "SQL" "SQL"
        reconciliation -> db "Đọc/ghi bảng của reconciliation" "SQL" "SQL"
        approval -> db "Đọc/ghi bảng của approval" "SQL" "SQL"
        ledger -> db "Đọc/ghi bảng của ledger" "SQL" "SQL"
        gateway -> db "Đọc/ghi bảng của gateway" "SQL" "SQL"
        semantic -> db "Đọc/ghi bảng của semantic" "SQL, pgvector" "SQL"
        invoice -> files "Lưu / đọc file gốc theo org_id/sha256"
        rules -> yaml "Đọc lúc khởi động"

        # Bên ngoài
        gateway -> openai "Structured output, temperature 0; embedding" "HTTPS" {
            tags "Chưa làm"
        }
        gateway -> documentAi "OCR" "HTTPS" {
            tags "Chưa làm"
        }
        gateway -> langsmith "Trace, chi phí" "HTTPS" {
            tags "Chưa làm"
        }
        reconciliation -> traCuuThue "Trạng thái mã số thuế (FRD-06)" "TaxAuthorityClient" {
            tags "Chưa làm"
        }
        erp -> phanMemKeToan "Lấy danh mục, đẩy bút toán" "ErpConnector" {
            tags "Chưa làm"
        }

        # ---- Quan hệ: mức 4 --------------------------------------------------------------------

        pipeline -> cService "run(ctx, invoice_id)"
        cRouter -> cReview "Gọi use case"
        cReview -> cService "Chạy lại sau khi gán lại đơn đặt hàng"
        cService -> cPolicyAcl "for_tenant(org_id)"
        cService -> cUow "begin(org_id)"
        cService -> cInvoiceAcl "load(invoice_id); mark_matched"
        cService -> cVendorAcl "load(mã số thuế)"
        cService -> cRetrieval "retrieve(side, vendor_id, tol, book)"
        cService -> cProcurementAcl "load(po_ids)"
        cService -> cLadder "match_all(side, procurement, vendor, tol)"
        cService -> cChecks "run_checks(ReconciliationContext)"
        cService -> cClassify "classify(severities, all_fields_confident)"
        cService -> cResults "Thay links, line_matches, discrepancies đang mở"
        cRetrieval -> cProcurementAcl "by_numbers, open_candidates, lines"
        cLadder -> cArbiter "choose(line, candidates)"
        cInconclusive -> cArbiter "Cài đặt"
        cLlmArbiter -> cArbiter "Cài đặt" {
            tags "Chưa làm"
        }
        cLlmArbiter -> gateway "StructuredLlm.complete" {
            tags "Chưa làm"
        }
        cUow -> cInvoiceAcl "Gắn vào connection"
        cUow -> cProcurementAcl "Gắn vào connection"
        cUow -> cVendorAcl "Gắn vào connection"
        cUow -> cResults "Gắn vào connection"
        cInvoiceAcl -> invoice "provided: InvoiceReader, InvoiceLifecycle"
        cProcurementAcl -> procurement "provided: ProcurementReader"
        cVendorAcl -> vendor "provided: VendorReader"
        cPolicyAcl -> rules "provided: TenantConfigs, ExceptionCatalog"
        cResults -> db "SQL" "psycopg 3"
    }

    views {

        systemContext p143 "L1-Context" "Mức 1 — Hệ thống phục vụ ai, nói chuyện với ai. Nhà cung cấp và phòng mua hàng không dùng hệ thống; dữ liệu của họ đi qua tay kế toán viên." {
            include *
            include nhaCungCap muaHang
            autolayout tb
        }

        container p143 "L2-Container" "Mức 2 — Các khối triển khai. Pipeline xử lý nền chạy chung tiến trình với API (xem mức 3)." {
            include *
            autolayout lr
        }

        component api "L3-Component" "Mức 3 — Module trong API. Mũi tên A → B: A đọc/ghi dữ liệu của B qua interface của B (repository/acl), không query bảng của B. Ẩn: quan hệ tới audit, tới cơ sở dữ liệu, và web (xem L2)." {
            include *
            exclude "element.tag==Code"
            exclude web db
            exclude "relationship.tag==Audit"
            autolayout lr
        }

        dynamic api "L3-InvoiceFlow" "Mức 3 — Một hóa đơn từ lúc tải lên tới lúc chốt bút toán." {
            web -> invoice "POST /invoices/upload"
            invoice -> files "Lưu file theo org_id/sha256"
            invoice -> pipeline "Xếp hàng đợi; API trả 202 + batch_id"
            pipeline -> invoice "Trích xuất"
            invoice -> extraction "XML trước, rồi PDF, rồi OCR"
            pipeline -> reconciliation "Đối chiếu"
            reconciliation -> procurement "Đơn đặt hàng, phiếu nhập kho"
            reconciliation -> invoice "EXTRACTED → MATCHED, gắn GREEN / YELLOW / RED"
            pipeline -> invoice "MATCHED → PENDING_L1"
            web -> reconciliation "POST /discrepancies/{id}/resolve"
            web -> approval "POST /invoices/{id}/approve"
            approval -> ledger "Soạn bút toán"
            approval -> invoice "→ APPROVED (hoặc PENDING_L2)"
            web -> ledger "POST /exports/journal"
            ledger -> invoice "APPROVED → POSTED"
            autolayout lr
        }

        component api "L4-Reconciliation" "Mức 4 — Lớp bên trong module reconciliation. Service chỉ biết interface; repository/acl là nơi duy nhất chạm module khác." {
            include "element.tag==Code"
            include pipeline invoice procurement vendor rules gateway db
            autolayout lr
        }

        dynamic api "L4-ReconcileRun" "Mức 4 — Một lần ReconcileInvoiceService.run: một transaction, số query cố định, không LLM." {
            pipeline -> cService "run(ctx, invoice_id)"
            cService -> cPolicyAcl "Nạp dung sai, thuế suất, mã ngoại lệ của tổ chức"
            cService -> cUow "Mở một transaction"
            cService -> cInvoiceAcl "Nạp hóa đơn, dòng, confidence"
            cService -> cVendorAcl "Nạp nhà cung cấp + quy tắc nhớ ACTIVE"
            cService -> cRetrieval "Tìm đơn đặt hàng (bỏ qua nếu đã gán thủ công)"
            cRetrieval -> cProcurementAcl "Bậc 1 theo số, bậc 2 theo mã số thuế + ngày"
            cService -> cProcurementAcl "Nạp đơn, dòng, phiếu nhập kho theo lô"
            cService -> cLadder "Khớp từng dòng L0 → L3"
            cLadder -> cArbiter "Dòng ở vùng mờ → L4"
            cService -> cChecks "Chạy mọi kiểm tra trên dữ liệu đã nạp"
            cService -> cClassify "GREEN / YELLOW / RED"
            cService -> cResults "Giữ ngoại lệ đã xử lý, thay phần còn lại"
            cService -> cInvoiceAcl "EXTRACTED → MATCHED, commit"
            autolayout lr
        }

        styles {
            element "Element" {
                fontSize 22
            }
            element "Person" {
                shape Person
                background #08427b
                color #ffffff
            }
            element "Software System" {
                background #1168bd
                color #ffffff
            }
            element "Container" {
                background #438dd5
                color #ffffff
            }
            element "Component" {
                background #85bbf0
                color #000000
            }
            element "Code" {
                background #dbeafe
                color #000000
            }
            element "Interface" {
                border dashed
                background #ffffff
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "Database" {
                shape Cylinder
            }
            element "Storage" {
                shape Folder
            }
            element "Web Browser" {
                shape WebBrowser
            }
            element "Đang làm" {
                background #f0ad4e
                color #000000
            }
            element "Chưa làm" {
                border dashed
                opacity 55
            }
            relationship "Relationship" {
                fontSize 20
            }
            relationship "Chưa làm" {
                style dashed
                opacity 55
            }
            relationship "Audit" {
                color #9e9e9e
            }
        }
    }

    configuration {
        scope softwaresystem
    }
}
