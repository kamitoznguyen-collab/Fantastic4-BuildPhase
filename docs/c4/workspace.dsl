/*
 * C4 — Invoice Reconciliation Agent (P-143)
 *
 * Vẽ theo code thật ở repo P-143, nhánh main tại 0ecb981 (10/10/2026). Cập nhật 13/10/2026.
 * Bản diễn giải bằng chữ: ../C4_DESIGN.md
 * Xem: docker compose up -d rồi mở http://localhost:8080
 *
 * Mức 1  L1-Context         ai dùng hệ thống, hệ thống nói chuyện với ai
 * Mức 2  L2-Container       các khối triển khai
 * Mức 3  L3-Component       14 module trong API và phụ thuộc giữa chúng
 *        L3-InvoiceFlow     một hóa đơn đi qua đồ thị LangGraph và các module
 * Mức 4  L4-Reconciliation  lớp bên trong module reconciliation
 *        L4-ReconcileRun    một lần ReconcileInvoiceService.run
 * Triển khai  Prod-Deployment  máy prod sau Cloudflare tunnel
 *
 * Tag trạng thái: "Đang làm" = có một phần, chưa đủ; "Chưa làm" = mới có interface hoặc chưa có.
 * Không gắn tag = đã chạy được, có test.
 */
workspace "Invoice Reconciliation Agent" "Đối soát hóa đơn ↔ đơn đặt hàng ↔ phiếu nhập kho cho kế toán phải trả. Pilot: Công ty X." {

    model {

        # ---- Người dùng và bên ngoài ------------------------------------------------------------

        ktv = person "Kế toán viên" "Tải hóa đơn lên, nhập đơn đặt hàng và phiếu nhập kho, xử lý chỗ lệch, duyệt cấp 1, xuất kết quả."
        ktt = person "Kế toán trưởng" "Duyệt cấp 2, cấu hình dung sai và ngưỡng duyệt, duyệt quy tắc nhà cung cấp, đồng bộ ERP, tra nhật ký."

        nhaCungCap = person "Nhà cung cấp" "Gửi hóa đơn điện tử (XML), PDF hoặc ảnh chụp qua email." {
            tags "External"
        }

        erpKhach = softwareSystem "ERP của khách" "Phát PO, phiếu nhập kho và file hóa đơn qua một feed tăng dần. Khi thử: eval/erp_sim." {
            tags "External"
        }
        phanMemKeToan = softwareSystem "Phần mềm kế toán" "MISA, Fast… Kế toán tự hạch toán từ file xuất. Hệ thống không sinh bút toán." {
            tags "External"
        }
        openrouter = softwareSystem "OpenRouter" "Cổng mô hình: Gemini 3.1 Flash-Lite đọc ảnh hóa đơn; mô hình chữ khớp dòng khó (L4) và xem lại truy hồi PO (B2, tắt mặc định)." {
            tags "External"
        }
        traCuuThue = softwareSystem "Tra cứu mã số thuế" "MST còn hoạt động không (FRD-06). Giả lập bằng config/mock/tax_lookup.yaml." {
            tags "External" "Đang làm"
        }
        langfuse = softwareSystem "Langfuse" "Một trace mỗi lượt xử lý hóa đơn, span mỗi bước, token và chi phí lời gọi mô hình. Bật khi có khóa." {
            tags "External"
        }
        cloudflare = softwareSystem "Cloudflare tunnel" "Đưa prod ra internet: c4-app-143. / api. / erp.fantasticfourr.stream." {
            tags "External"
        }

        # ---- Hệ thống ---------------------------------------------------------------------------

        p143 = softwareSystem "Hệ thống đối soát hóa đơn" "Đọc hóa đơn, tìm đơn đặt hàng và phiếu nhập kho, đối chiếu từng dòng, phân loại chỗ lệch, đề xuất cách xử lý, chuyển duyệt. Không tự duyệt, không sinh bút toán, không thanh toán." {

            web = container "Ứng dụng web" "Tổng quan, tải lên, lô, danh sách hóa đơn, so sánh 3 chiều, ngoại lệ, chờ duyệt, NCC, đơn hàng & phiếu nhập, cấu hình, nhật ký, chi phí. Prod: bản build sau nginx." "React + TypeScript (Vite)" {
                tags "Web Browser"
            }

            db = container "Cơ sở dữ liệu" "Dữ liệu nghiệp vụ mọi tổ chức (mọi bảng có org_id), nhật ký chỉ-thêm, cấu hình theo phiên bản, bảng jobs, checkpoint của LangGraph. Migration SQL thuần 0001…0016 có checksum." "PostgreSQL 18 (uuidv7) + pgvector" {
                tags "Database"
            }

            files = container "Kho file gốc" "File hóa đơn gốc, khóa org_id/sha256. Tải lên / tải xuống qua URL ký sẵn." "MinIO (S3) ở stage, prod; ổ đĩa ở dev" {
                tags "Storage"
            }

            yaml = container "Cấu hình mặc định" "Dung sai, thuế suất theo ngày hiệu lực, nhóm thuế, chính sách duyệt, giới hạn, luật khớp dòng. Đọc và kiểm tra lúc khởi động." "config/*.yaml" {
                tags "Storage"
            }

            worker = container "Worker" "Chạy job từ bảng jobs (LISTEN/NOTIFY) khi QUEUE_BACKEND=postgres: bước đồ thị, tính lại readiness hằng đêm, dọn phiên tải lên. Server hiện chạy QUEUE_BACKEND=inline nên đồ thị chạy trong API." "cùng image, python -m src.app.cli.worker"

            api = container "API" "Modular monolith 14 module, REST /api/v1 (65 endpoint), JWT, phân quyền. Đồ thị LangGraph điều phối từng hóa đơn; kéo feed ERP theo lịch." "Python, FastAPI, uvicorn, psycopg 3 async, SQL thuần" {

                # ---- Mức 3: tầng app ---------------------------------------------------------

                group "Nền tảng" {
                    core = component "core" "DB pool, TenantUnitOfWork (một transaction cho một tổ chức), xác thực token, tiền Decimal, mã ngoại lệ (vocab), migrate, tracing Langfuse." "src/core"
                    wiring = component "app.wiring" "Composition root: nơi duy nhất biết class cụ thể của mọi module; gắn repository và adapter chéo vào cùng một connection." "src/app/wiring/"
                    graph = component "app.graph" "LangGraph, bộ điều phối duy nhất. Mỗi hóa đơn một thread: trích xuất → chỗ dừng đọc (READING_REVIEW) → đối chiếu → chờ phiếu nhập / chuyển duyệt. Dừng chờ người bằng interrupt; checkpoint trong PostgreSQL; sweeper đánh thức thread đang chờ." "src/app/graph/"
                    erpRunner = component "app.integrations.erp_runner" "Gọi ErpSync.pull theo ERP_PULL_INTERVAL_SECONDS (prod: 4 giờ)." "src/app/integrations/"
                }

                # ---- Mức 3: module ----------------------------------------------------------

                group "Quản trị" {
                    iam = component "iam" "Đăng nhập, access/refresh token, thu hồi, khóa tài khoản sau 5 lần sai. Bảng: orgs, users, sessions, revoked_access_tokens, login_attempts." "module"
                    rules = component "rules" "Cấu hình theo tổ chức (config_versions mới nhất đè lên YAML, có cache), danh mục mã ngoại lệ, đọc tiền bằng chữ. Bảng: config_versions." "module"
                    audit = component "audit" "Nhật ký cho mọi module, trong transaction của bên gọi; lọc và xuất cho kiểm toán. Bảng: audit_logs (chỉ INSERT, SELECT)." "module"
                }

                group "Danh mục" {
                    vendor = component "vendor" "Nhà cung cấp, quy tắc nhớ (tên hàng, quy đổi đơn vị, dung sai riêng), học alias PROPOSED từ lần gán tay, tài khoản ngân hàng đã xác minh. Bảng: vendors, vendor_rules." "module"
                    procurement = component "procurement" "Nhập PO, phiếu nhập kho từ Excel / CSV / JSON / file Nhập kho của MISA AMIS; sổ số lượng đã nhận, đã hóa đơn từng dòng. Bảng: purchase_orders, po_lines, goods_receipts, grn_lines, po_line_invoicings." "module"
                    erp = component "erp" "ErpSync kéo NCC → PO → phiếu nhập → file hóa đơn từ feed theo con trỏ (HttpFeedConnector); chưa đẩy ngược sang ERP. Bảng: sync_runs." "module" {
                        tags "Đang làm"
                    }
                }

                group "Tiếp nhận" {
                    invoice = component "invoice" "Tải lên (thường và qua URL ký sẵn), lô, chống trùng sha256, máy trạng thái hóa đơn, ghi kết quả trích xuất, sửa và xác nhận trường, nhập tay. Bảng: files, upload_sessions, upload_batches, invoices, invoice_lines, extraction_fields." "module"
                    extraction = component "extraction" "Chọn cách đọc rẻ nhất: XML TT78 → PDF có text → ảnh. OCR_MODE=graph (mẫu bố cục, rồi mô hình thị giác) ở dev; OCR_MODE=demo (đọc mỗi trang 2 lần) ở stage, prod." "module"
                }

                group "Đối chiếu" {
                    reconciliation = component "reconciliation" "Truy hồi PO / GRN (bậc 1–2; B1, B2 theo cờ), khớp dòng theo matching.yaml, kiểm toàn vẹn, dung sai, thuế, bất thường; phân loại GREEN / YELLOW / RED; xử lý ngoại lệ; gán PO và gán dòng bằng tay. Bảng: invoice_po_links, line_matches, line_match_overrides, discrepancies, invoice_tax_assessments." "module"
                }

                group "Sau đối chiếu" {
                    approval = component "approval" "Duyệt, từ chối, trả lại; quyết định có cần cấp 2; tách người duyệt; ghi số lượng đã hóa đơn khi duyệt xong. Bảng: approvals." "module" {
                        tags "Đang làm"
                    }
                    export = component "export" "Xuất hóa đơn đã duyệt, báo cáo đối soát, nhật ký ra Excel / CSV; hóa đơn đã xuất chuyển EXPORTED. Không sinh bút toán (PRD F10). Không có bảng riêng." "module"
                    reporting = component "reporting" "Danh sách công việc, tổng quan, điểm sẵn sàng tự động hóa của NCC, chi phí. Không có bảng riêng." "module"
                }

                group "AI" {
                    gateway = component "gateway" "Cổng duy nhất ra mô hình qua OpenRouter: structured output temperature 0, đọc ảnh; ngân sách ngày, cache, ghi chi phí. Chưa có Embedder. Bảng: ai_calls, ai_cache." "module" {
                        tags "Đang làm"
                    }
                    semantic = component "semantic" "Tìm PO theo vector (bậc 3 truy hồi). Mới có domain, interface, bảng. Bảng: embeddings." "module" {
                        tags "Chưa làm"
                    }
                }

                # ---- Mức 4: code bên trong reconciliation --------------------------------------

                group "reconciliation — code" {
                    cRouter = component "router" "So sánh 3 chiều, ngoại lệ, resolve, relink-po, gán dòng, chạy đối chiếu ngay." "handler/router.py" {
                        tags "Code"
                    }
                    cReview = component "DefaultReconciliationReview" "Xử lý ngoại lệ (bắt buộc lý do khi khác đề xuất), gán lại PO rồi chạy lại." "service/review.py" {
                        tags "Code"
                    }
                    cAssign = component "DefaultLineAssignment" "Gán một dòng hóa đơn vào dòng PO hoặc 'không thuộc PO nào'; ghi line_match_overrides, học alias cho vendor." "service/line_assignment.py" {
                        tags "Code"
                    }
                    cService = component "ReconcileInvoiceService" "Một transaction, số query cố định; mọi kiểm tra là hàm thuần." "service/reconcile_invoice.py" {
                        tags "Code"
                    }
                    cRetrieval = component "TieredDocumentRetrieval" "Bậc 1: số PO in trên hóa đơn. Bậc 2: MST + khoảng ngày, chấm điểm ứng viên; DOC-01, DOC-04, DOC-06." "service/retrieval.py" {
                        tags "Code"
                    }
                    cRulesRetrieval = component "RulesDocumentRetrieval" "B1 (RETRIEVAL_RULES): chuẩn hóa và kiểm số PO với NCC và dòng, sửa một ký tự, nới khoảng ngày một lần, phân định PO ngang điểm. Tắt mặc định." "service/retrieval_rules.py" {
                        tags "Code"
                    }
                    cRefiner = component "ChooserRefiner" "B2 (RETRIEVAL_LLM): mô hình xếp thứ tự PO đưa người chọn, xem lại liên kết chỉ theo NCC + ngày; không tự gắn PO. Tắt mặc định." "service/retrieval_refiner.py" {
                        tags "Code"
                    }
                    cLadder = component "LadderLineMatching" "Thang khớp dòng: L0 mã hàng, L1 quy tắc nhớ, L2 chuỗi chuẩn hóa, L3 so chuỗi mờ (BM25 + token_set_ratio, RRF); đơn giá làm bằng chứng; vùng mờ chuyển arbiter." "service/line_matching.py, domain/matching" {
                        tags "Code"
                    }
                    cArbiter = component "LineMatchArbiter" "Interface L4: chọn một trong các ứng viên hoặc từ chối. Câu trả lời ngoài danh sách bị bỏ." "domain/contracts/required.py" {
                        tags "Code" "Interface"
                    }
                    cLlmArbiter = component "LlmLineArbiter" "Mô hình chọn trong ứng viên, không thấy giá và số lượng; cặp được chọn luôn thành ITM-02, người xác nhận." "repository/acl/gateway.py" {
                        tags "Code"
                    }
                    cInconclusive = component "InconclusiveArbiter" "Dùng khi không có khóa mô hình: luôn từ chối, dòng thành ITM-01." "service/arbiter.py" {
                        tags "Code"
                    }
                    cChecks = component "run_checks" "Hàm thuần trên ReconciliationContext: integrity (F3), tolerance (F6), tax (F7), lines (F5), fraud (F8)." "domain/checks" {
                        tags "Code"
                    }
                    cClassify = component "classify" "BLOCK → RED, REVIEW → YELLOW, còn lại GREEN; còn trường cần xem thì không được GREEN." "domain/classification.py" {
                        tags "Code"
                    }
                    cExplain = component "TemplateExplanationWriter" "Câu giải thích chỉ từ dữ kiện có cấu trúc, kèm công thức và số tiền." "service/explanation.py, domain/explanation" {
                        tags "Code"
                    }
                    cUow = component "PostgresReconciliationUnitOfWork" "Một transaction cho một tổ chức; repository của module và adapter sang module khác dùng chung connection." "repository/postgres/unit_of_work.py" {
                        tags "Code"
                    }
                    cResults = component "Postgres repositories" "Ghi invoice_po_links, line_matches, discrepancies, line_match_overrides, invoice_tax_assessments." "repository/postgres/" {
                        tags "Code"
                    }
                    cInvoiceAcl = component "acl → invoice" "Nạp hóa đơn, dòng, độ tin cậy; chuyển EXTRACTED → MATCHED." "repository/acl/invoice.py" {
                        tags "Code"
                    }
                    cProcurementAcl = component "acl → procurement" "Tìm theo số, ứng viên đang mở, nạp PO + dòng + phiếu nhập theo lô." "repository/acl/procurement.py" {
                        tags "Code"
                    }
                    cVendorAcl = component "acl → vendor" "NCC theo MST + quy tắc nhớ ACTIVE; ghi bằng chứng alias khi người gán tay." "repository/acl/vendor.py, vendor_learning.py" {
                        tags "Code"
                    }
                    cPolicyAcl = component "acl → rules" "Dung sai nhiều tầng, thuế suất theo ngày, luật khớp, danh mục mã ngoại lệ." "repository/acl/rules.py" {
                        tags "Code"
                    }
                }
            }
        }

        # ---- Quan hệ: mức 1 --------------------------------------------------------------------

        nhaCungCap -> ktv "Gửi hóa đơn qua email"
        ktv -> phanMemKeToan "Nhập file hóa đơn đã duyệt, tự hạch toán"

        # ---- Quan hệ: mức 2 --------------------------------------------------------------------

        ktv -> web "Tải hóa đơn, nhập chứng từ, đối soát, duyệt cấp 1, xuất kết quả" "HTTPS"
        ktt -> web "Duyệt cấp 2, cấu hình, đồng bộ ERP, tra nhật ký" "HTTPS"
        web -> files "Tải file lên / xuống bằng URL ký sẵn" "HTTPS"
        worker -> db "Nhận job (LISTEN), đọc / ghi" "SQL"
        worker -> files "Đọc file gốc"
        worker -> openrouter "Qua module gateway" "HTTPS"

        # ---- Quan hệ: mức 3, web gọi module -----------------------------------------------------

        web -> iam "Đăng nhập, làm mới token" "REST + JSON" "REST"
        web -> invoice "Tải lên, lô, xem, sửa / xác nhận trường, nhập tay, xử lý lại" "REST + JSON, Bearer JWT" "REST"
        web -> reconciliation "So sánh 3 chiều, xử lý ngoại lệ, gán PO, gán dòng" "REST + JSON, Bearer JWT" "REST"
        web -> approval "Duyệt, từ chối, trả lại, hàng đợi" "REST + JSON, Bearer JWT" "REST"
        web -> export "Xuất hóa đơn đã duyệt, báo cáo đối soát" "REST + JSON, Bearer JWT" "REST"
        web -> reporting "Danh sách, tổng quan, điểm sẵn sàng, chi phí" "REST + JSON, Bearer JWT" "REST"
        web -> vendor "Nhà cung cấp, quy tắc nhớ, tài khoản ngân hàng" "REST + JSON, Bearer JWT" "REST"
        web -> procurement "Nhập PO, phiếu nhập kho" "REST + JSON, Bearer JWT" "REST"
        web -> erp "Đồng bộ ngay, lịch sử đồng bộ" "REST + JSON, Bearer JWT" "REST"
        web -> rules "Xem, sửa cấu hình" "REST + JSON, Bearer JWT" "REST"
        web -> audit "Tra, xuất nhật ký" "REST + JSON, Bearer JWT" "REST"

        # ---- Quan hệ: mức 3, điều phối ---------------------------------------------------------

        invoice -> graph "Mở thread cho hóa đơn mới; tiếp tục thread sau khi người sửa"
        graph -> invoice "Trích xuất; chỗ dừng đọc; chuyển PENDING_L1"
        graph -> reconciliation "Đối chiếu; chờ phiếu nhập"
        graph -> approval "Chuyển duyệt"
        erpRunner -> erp "pull() theo lịch"

        # ---- Quan hệ: mức 3, giữa các module (chỉ qua repository/acl) ---------------------------

        invoice -> extraction "Đọc file thành trường + độ tin cậy + bằng chứng"
        invoice -> rules "Giới hạn tải lên"
        invoice -> vendor "Nhận diện NCC theo MST"
        extraction -> gateway "Đọc ảnh, mô hình chữ"
        extraction -> rules "Luật đọc, ngưỡng"
        gateway -> rules "Ngân sách ngày"
        semantic -> gateway "Tạo embedding" {
            tags "Chưa làm"
        }
        procurement -> vendor "Tra / tạo NCC khi nhập"
        erp -> procurement "Ghi PO, phiếu nhập kéo về"
        erp -> vendor "Ghi NCC kéo về"
        erp -> invoice "Nạp file hóa đơn kéo về (cùng giới hạn, chống trùng)"
        reconciliation -> invoice "Đọc hóa đơn; chuyển MATCHED"
        reconciliation -> procurement "Đọc PO, phiếu nhập kho"
        reconciliation -> vendor "Đọc quy tắc nhớ; ghi bằng chứng alias"
        reconciliation -> rules "Dung sai, thuế suất, luật khớp, mã ngoại lệ"
        reconciliation -> gateway "Khớp dòng L4, xem lại truy hồi B2"
        approval -> invoice "Chuyển PENDING_L2 / APPROVED / RETURNED / REJECTED"
        approval -> reconciliation "Đọc ngoại lệ đang mở, dòng đã khớp"
        approval -> procurement "Ghi số lượng đã hóa đơn"
        approval -> rules "Chính sách duyệt"
        approval -> vendor "NCC mới?"
        export -> approval "Hóa đơn đã duyệt"
        export -> invoice "Đọc hóa đơn; chuyển EXPORTED"
        export -> reconciliation "Ngoại lệ, dòng đã khớp"
        export -> procurement "Số PO, phiếu nhập"
        export -> vendor "Tên, MST NCC"
        export -> iam "Tên người duyệt"
        reporting -> invoice "Tìm kiếm, thống kê hóa đơn"
        reporting -> reconciliation "Thống kê ngoại lệ"
        reporting -> approval "Lịch sử duyệt"
        reporting -> vendor "Ghi điểm sẵn sàng"

        # Nhật ký: mọi module có ghi dữ liệu đều ghi audit trong cùng transaction
        iam -> audit "Ghi nhật ký" "" "Audit"
        rules -> audit "Ghi nhật ký" "" "Audit"
        vendor -> audit "Ghi nhật ký" "" "Audit"
        invoice -> audit "Ghi nhật ký" "" "Audit"
        reconciliation -> audit "Ghi nhật ký" "" "Audit"
        approval -> audit "Ghi nhật ký" "" "Audit"
        export -> audit "Ghi nhật ký" "" "Audit"
        reporting -> audit "Đọc nhật ký" "" "Audit"

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
        gateway -> db "Đọc/ghi bảng của gateway" "SQL" "SQL"
        semantic -> db "Đọc/ghi bảng của semantic" "SQL, pgvector" "SQL"
        graph -> db "Checkpoint, jobs" "SQL" "SQL"
        invoice -> files "Lưu / đọc file gốc theo org_id/sha256"
        rules -> yaml "Đọc lúc khởi động"

        # Bên ngoài
        gateway -> openrouter "Structured output temperature 0; đọc ảnh" "HTTPS"
        core -> langfuse "Trace, token, chi phí (bỏ ảnh, che số tài khoản)" "HTTPS"
        reconciliation -> traCuuThue "Trạng thái MST (FRD-06)" "TaxAuthorityClient"
        erp -> erpKhach "Kéo feed theo con trỏ" "HTTPS"
        erp -> phanMemKeToan "Đẩy hóa đơn đã duyệt (F17.4)" "ErpConnector" {
            tags "Chưa làm"
        }
        cloudflare -> web "Chuyển tiếp c4-app-143.fantasticfourr.stream" "HTTPS"
        cloudflare -> api "Chuyển tiếp api.fantasticfourr.stream" "HTTPS"

        # ---- Quan hệ: mức 4 --------------------------------------------------------------------

        graph -> cService "run(ctx, invoice_id)"
        cRouter -> cReview "Xử lý ngoại lệ, gán lại PO"
        cRouter -> cAssign "Gán dòng"
        cReview -> cService "Chạy lại sau khi gán lại PO"
        cAssign -> cService "Chạy lại sau khi gán dòng"
        cAssign -> cVendorAcl "Ghi bằng chứng alias"
        cService -> cPolicyAcl "for_tenant(org_id)"
        cService -> cUow "begin(org_id)"
        cService -> cInvoiceAcl "load(invoice_id); mark_matched"
        cService -> cVendorAcl "load(MST)"
        cService -> cRetrieval "retrieve (RETRIEVAL_RULES tắt)"
        cService -> cRulesRetrieval "retrieve (RETRIEVAL_RULES bật)"
        cService -> cRefiner "Xem lại kết quả truy hồi (RETRIEVAL_LLM bật)"
        cService -> cProcurementAcl "load(po_ids)"
        cService -> cLadder "match_all"
        cService -> cChecks "run_checks(ReconciliationContext)"
        cService -> cClassify "classify"
        cService -> cExplain "Viết giải thích cho từng ngoại lệ"
        cService -> cResults "Thay links, line_matches, discrepancies đang mở"
        cRetrieval -> cProcurementAcl "by_numbers, open_candidates"
        cRulesRetrieval -> cProcurementAcl "by_numbers, open_candidates, lines"
        cRefiner -> gateway "StructuredLlm.complete"
        cLadder -> cArbiter "choose(line, candidates)"
        cLlmArbiter -> cArbiter "Cài đặt"
        cInconclusive -> cArbiter "Cài đặt"
        cLlmArbiter -> gateway "StructuredLlm.complete"
        cUow -> cInvoiceAcl "Gắn vào connection"
        cUow -> cProcurementAcl "Gắn vào connection"
        cUow -> cVendorAcl "Gắn vào connection"
        cUow -> cResults "Gắn vào connection"
        cInvoiceAcl -> invoice "provided: InvoiceReader, InvoiceLifecycle"
        cProcurementAcl -> procurement "provided: ProcurementReader"
        cVendorAcl -> vendor "provided: VendorReader, alias learning"
        cPolicyAcl -> rules "provided: TenantConfigs, ExceptionCatalog"
        cResults -> db "SQL" "psycopg 3"

        # ---- Triển khai: prod -------------------------------------------------------------------

        prod = deploymentEnvironment "Prod" {
            deploymentNode "Cloudflare" "Tunnel công khai" "Cloudflare" {
                infrastructureNode "cloudflared" "Ba tên miền: c4-app-143., api., erp.fantasticfourr.stream" "Cloudflare tunnel"
            }
            deploymentNode "Máy prod" "Docker Compose, project p143-prod (deploy/compose.yml + compose.prod.yml)" "Docker" {
                deploymentNode "frontend" "" "nginx" {
                    containerInstance web
                }
                deploymentNode "backend" "Chỉ mở 127.0.0.1:28000; OCR_MODE=demo, READING_REVIEW=true" "python" {
                    containerInstance api
                }
                deploymentNode "db" "" "pgvector/pgvector:pg18" {
                    containerInstance db
                }
                deploymentNode "minio" "URL ký sẵn qua s3.fantasticfourr.stream" "MinIO" {
                    containerInstance files
                }
                deploymentNode "observability (tùy chọn)" "Prometheus, Loki, Alloy, Grafana; cổng chỉ mở loopback" "Docker" {
                    infrastructureNode "grafana" "Bảng số đo, cảnh báo" "Grafana"
                }
            }
        }
    }

    views {

        systemContext p143 "L1-Context" "Mức 1 — Hệ thống phục vụ ai, nói chuyện với ai. Nhà cung cấp không dùng hệ thống; hóa đơn của họ đi qua tay kế toán viên, hoặc qua feed ERP." {
            include *
            include nhaCungCap
            exclude cloudflare
            autolayout tb
        }

        container p143 "L2-Container" "Mức 2 — Các khối triển khai. Đồ thị LangGraph chạy trong API (QUEUE_BACKEND=inline) hoặc trong worker (postgres)." {
            include *
            autolayout lr
        }

        component api "L3-Component" "Mức 3 — Module trong API. Mũi tên A → B: A đọc/ghi dữ liệu của B qua interface của B (repository/acl), không query bảng của B. Ẩn: quan hệ tới audit, tới cơ sở dữ liệu, và web (xem L2)." {
            include *
            exclude "element.tag==Code"
            exclude web db cloudflare
            exclude "relationship.tag==Audit"
            autolayout lr
        }

        dynamic api "L3-InvoiceFlow" "Mức 3 — Một hóa đơn từ lúc tải lên tới lúc xuất cho kế toán." {
            web -> invoice "POST /invoices/upload"
            invoice -> files "Lưu file theo org_id/sha256"
            invoice -> graph "Mở thread; API trả 202 + batch_id"
            graph -> invoice "Trích xuất; dừng ở chỗ đọc nếu có trường cần xem"
            invoice -> extraction "XML trước, rồi PDF text, rồi ảnh"
            extraction -> gateway "Đọc ảnh qua OpenRouter"
            web -> invoice "Xác nhận / sửa trường, xong bản đọc"
            graph -> reconciliation "Đối chiếu"
            reconciliation -> procurement "PO, phiếu nhập kho"
            reconciliation -> invoice "EXTRACTED → MATCHED, gắn GREEN / YELLOW / RED"
            graph -> invoice "MATCHED → PENDING_L1"
            web -> reconciliation "Xử lý ngoại lệ, gán PO, gán dòng"
            web -> approval "POST /invoices/{id}/approve"
            approval -> invoice "→ APPROVED (hoặc PENDING_L2)"
            web -> export "POST /exports/approved-invoices"
            export -> invoice "APPROVED → EXPORTED"
            autolayout lr
        }

        component api "L4-Reconciliation" "Mức 4 — Lớp bên trong module reconciliation. Service chỉ biết interface; repository/acl là nơi duy nhất chạm module khác." {
            include "element.tag==Code"
            include graph invoice procurement vendor rules gateway db
            autolayout lr
        }

        dynamic api "L4-ReconcileRun" "Mức 4 — Một lần ReconcileInvoiceService.run: một transaction, số query cố định." {
            graph -> cService "run(ctx, invoice_id)"
            cService -> cPolicyAcl "Nạp dung sai, thuế suất, luật khớp, mã ngoại lệ của tổ chức"
            cService -> cUow "Mở một transaction"
            cService -> cInvoiceAcl "Nạp hóa đơn, dòng, độ tin cậy"
            cService -> cVendorAcl "Nạp NCC + quy tắc nhớ ACTIVE"
            cService -> cRetrieval "Tìm PO (bỏ qua nếu đã gán thủ công)"
            cRetrieval -> cProcurementAcl "Bậc 1 theo số, bậc 2 theo MST + ngày"
            cService -> cProcurementAcl "Nạp PO, dòng, phiếu nhập kho theo lô"
            cService -> cLadder "Khớp từng dòng L0 → L3"
            cLadder -> cArbiter "Dòng ở vùng mờ → L4"
            cService -> cChecks "Chạy mọi kiểm tra trên dữ liệu đã nạp"
            cService -> cClassify "GREEN / YELLOW / RED"
            cService -> cExplain "Câu giải thích từ dữ kiện có cấu trúc"
            cService -> cResults "Giữ ngoại lệ đã xử lý, thay phần còn lại"
            cService -> cInvoiceAcl "EXTRACTED → MATCHED, commit"
            autolayout lr
        }

        deployment p143 "Prod" "Prod-Deployment" "Triển khai prod (PR #23, 09/10/2026): một máy chạy Docker Compose, ra internet qua Cloudflare tunnel." {
            include *
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
