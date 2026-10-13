# Thiết kế C4 — Invoice Reconciliation Agent

> Kiến trúc hệ thống theo mô hình C4, từ tổng quan tới code · Ngày 23/09/2026, cập nhật Mức 1–3 ngày 13/10/2026
> Vẽ theo code thật ở repo `P-143`: Mức 1–3 theo `main` tại `0ecb981` (10/10/2026); Mức 4 vẫn theo nhánh `feat/module-api` (23/09)
> Tài liệu liên quan: `PRD.md` (yêu cầu) · `USER_STORIES.md` (tình huống nghiệp vụ) · `P-143/src/module/README.md` (quy tắc module)

**Bản tương tác:** cùng mô hình viết bằng Structurizr DSL ở `docs/c4/workspace.dsl`, có thêm góc nhìn triển khai prod. Xem: `cd docs/c4 && docker compose up -d` rồi mở `http://localhost:8080`.

**C4 là gì.** Bốn mức phóng to dần, mỗi mức trả lời một câu hỏi:

| Mức | Tên | Câu hỏi |
|---|---|---|
| 1 | System Context — bối cảnh | Hệ thống phục vụ ai, nói chuyện với hệ thống nào bên ngoài? |
| 2 | Container — khối triển khai | Hệ thống gồm những khối chạy riêng nào: ứng dụng, cơ sở dữ liệu, kho file? |
| 3 | Component — thành phần | Bên trong khối API chia thành những module nào, module nào phụ thuộc module nào? |
| 4 | Code | Một module được viết thế nào: interface, class, luồng gọi? |

**Ký hiệu trạng thái** dùng trong toàn tài liệu:

| Ký hiệu | Nghĩa |
|---|---|
| ✅ | Đã chạy được, có test |
| 🚧 | Đã có interface hoặc khung, chưa có phần chạy thật |
| ⏳ | Chưa làm |

---

## Mức 1 — Bối cảnh hệ thống

```mermaid
flowchart TB
    ktv["👤 Kế toán viên<br/><i>Tải hóa đơn, nhập PO và phiếu nhập,<br/>xử lý chỗ lệch, duyệt cấp 1, xuất kết quả</i>"]
    ktt["👤 Kế toán trưởng<br/><i>Duyệt cấp 2, cấu hình dung sai,<br/>duyệt quy tắc nhà cung cấp, xem nhật ký</i>"]

    sys["<b>Hệ thống đối soát hóa đơn</b><br/><i>Đọc hóa đơn, tìm đơn đặt hàng và phiếu nhập kho,<br/>đối chiếu từng dòng, phân loại chỗ lệch,<br/>đề xuất cách xử lý, chuyển duyệt</i>"]

    ncc["🏢 Nhà cung cấp<br/><i>Gửi hóa đơn điện tử qua email</i>"]
    erp["🖥 ERP của khách<br/><i>Phát PO, phiếu nhập, file hóa đơn<br/>qua một feed tăng dần</i>"]
    pmkt["🖥 Phần mềm kế toán<br/><i>MISA, Fast… — kế toán tự hạch toán</i>"]
    ai["☁️ OpenRouter<br/><i>Gemini 3.1 Flash-Lite đọc ảnh,<br/>mô hình chữ khớp dòng khó</i>"]
    thue["☁️ Tra cứu mã số thuế<br/><i>Giả lập bằng file YAML</i>"]

    ncc -. "hóa đơn XML / PDF / ảnh<br/>(kế toán viên tải lên)" .-> ktv
    ktv -- "tải hóa đơn, nhập Excel / CSV / JSON,<br/>đối soát, duyệt" --> sys
    ktt -- "duyệt cấp 2, cấu hình,<br/>tra nhật ký" --> sys
    erp -- "kéo theo lịch hoặc khi bấm" --> sys
    sys -- "file Excel / CSV hóa đơn đã duyệt" --> pmkt
    sys -- "đọc ảnh hóa đơn,<br/>khớp tên hàng khó" --> ai
    sys -- "mã số thuế còn hoạt động?" --> thue

    classDef person fill:#08427b,color:#fff,stroke:#052e56
    classDef system fill:#1168bd,color:#fff,stroke:#0b4884
    classDef external fill:#999,color:#fff,stroke:#6b6b6b
    class ktv,ktt person
    class sys system
    class ncc,erp,pmkt,ai,thue external
```

**Ranh giới cần nhớ**

- Hệ thống **không nhận email trực tiếp** từ nhà cung cấp. Hóa đơn vào qua kế toán viên tải lên, hoặc qua feed ERP.
- Hệ thống **không sinh bút toán và không ghi sổ** (PRD F10.1). Nó dừng ở hóa đơn đã duyệt và file xuất; hóa đơn đã xuất chuyển `EXPORTED`.
- Hệ thống **không thanh toán**.
- Dịch vụ AI chỉ được gọi ở các chỗ: đọc hóa đơn không phải XML, khớp tên hàng khó (bậc L4), và xem lại truy hồi PO khi bật `RETRIEVAL_LLM`. **Không có con số nào do AI quyết**: mọi cặp khớp do mô hình đề xuất đều cần người xác nhận.
- Đi ra ngoài chỉ qua một cổng (`gateway`), một khóa `OPENROUTER_API_KEY`. Không có khóa thì PDF / ảnh chuyển sang nhập tay.

---

## Mức 2 — Các khối triển khai

```mermaid
flowchart TB
    ktv["👤 Kế toán viên"]
    ktt["👤 Kế toán trưởng"]

    subgraph sys["Hệ thống đối soát hóa đơn"]
        web["<b>Ứng dụng web</b> ✅<br/><i>React + TypeScript (Vite)</i><br/>prod: bản build sau nginx"]
        api["<b>API</b> ✅<br/><i>Python, FastAPI, uvicorn</i><br/>REST /api/v1, JWT, 14 module,<br/>đồ thị LangGraph"]
        worker["<b>Worker</b> ✅<br/><i>cùng image, src.app.cli.worker</i><br/>chạy job khi QUEUE_BACKEND=postgres"]
        db[("<b>Cơ sở dữ liệu</b> ✅<br/><i>PostgreSQL 18 + pgvector</i><br/>dữ liệu nghiệp vụ, jobs,<br/>checkpoint LangGraph")]
        files[("<b>Kho file gốc</b> ✅<br/><i>MinIO (S3) ở stage / prod,<br/>ổ đĩa ở dev</i><br/>khóa org_id/sha256")]
        yaml["<b>Cấu hình mặc định</b> ✅<br/><i>config/*.yaml trong image</i><br/>dung sai, thuế suất, ngưỡng duyệt,<br/>giới hạn, luật khớp"]
    end

    tunnel["☁️ Cloudflare tunnel<br/><i>chỉ prod</i>"]
    openrouter["☁️ OpenRouter ✅"]
    erpfeed["🖥 Feed ERP<br/><i>erp_sim khi thử</i>"]
    langfuse["☁️ Langfuse ✅<br/><i>bật khi có khóa</i>"]

    ktv & ktt -- "HTTPS" --> tunnel --> web
    web -- "REST + JSON, Bearer JWT" --> api
    web -- "URL ký sẵn: tải file lên / xuống" --> files
    api -- "SQL, psycopg 3 async" --> db
    worker -- "SQL, LISTEN / NOTIFY" --> db
    api & worker -- "ghi / đọc file" --> files
    api -- "đọc lúc khởi động" --> yaml
    api & worker -. "qua module gateway" .-> openrouter
    api -- "kéo theo lịch" --> erpfeed
    api -. "trace" .-> langfuse

    classDef person fill:#08427b,color:#fff,stroke:#052e56
    classDef container fill:#438dd5,color:#fff,stroke:#2e6295
    classDef external fill:#999,color:#fff,stroke:#6b6b6b
    class ktv,ktt person
    class web,api,worker,db,files,yaml container
    class tunnel,openrouter,erpfeed,langfuse external
```

| Khối | Công nghệ | Trạng thái | Ghi chú |
|---|---|:-:|---|
| Ứng dụng web | React + TypeScript (Vite) | ✅ | Ở `frontend/`. Prod phục vụ bản build qua nginx |
| API | FastAPI, uvicorn, psycopg 3 async, SQL thuần, không ORM | ✅ | 65 endpoint (PRD §8), Swagger tại `/docs`, `GET /health` |
| Điều phối | LangGraph 1.2, checkpoint trong PostgreSQL | ✅ | Bộ điều phối duy nhất từ 07/10/2026 (bỏ `inprocess`). Mỗi hóa đơn một thread; dừng bằng `interrupt` ở chỗ chờ người (đọc, sửa, chờ phiếu nhập); sweeper đánh thức thread đang chờ |
| Worker | cùng image | ✅ | Chỉ chạy khi `QUEUE_BACKEND=postgres`. Mặc định của server hiện là `inline`: đồ thị chạy trong tiến trình API |
| Cơ sở dữ liệu | PostgreSQL 18 (`uuidv7()`), pgvector | ✅ | Migration SQL thuần `migrations/0001…0016`, mỗi file có checksum |
| Kho file gốc | `STORAGE_BACKEND=s3` (MinIO) ở stage / prod, `local` ở dev | ✅ | Trùng `sha256` trong cùng tổ chức thì không lưu lại |
| Cấu hình mặc định | YAML | ✅ | KTT sửa qua API thì lưu bản mới ở `config_versions`, đè lên YAML. File YAML hỏng thì API không khởi động |

**Theo dõi:** mỗi lượt pipeline chạy qua một hóa đơn là một trace Langfuse, mỗi bước (trích xuất, đọc ảnh, đối chiếu, chuyển duyệt) là một span, lời gọi mô hình đọc ảnh ghi token và chi phí. Không gửi ảnh hóa đơn, số tài khoản chỉ giữ 4 số cuối. Không có khóa `LANGFUSE_*` thì tắt. Số đo hệ thống (Prometheus, Loki, Alloy, Grafana) chạy riêng, chỉ mở trong mạng nội bộ của máy prod.

**Môi trường:** ba môi trường dev / stage / prod chạy bằng Docker Compose (`deploy/`), mỗi môi trường một database. Prod ra internet qua Cloudflare tunnel ở `c4-app-143.`, `api.`, `erp.fantasticfourr.stream`. Chi tiết ở PRD §10.1.

**Đa tổ chức** được đảm bảo ở khối API, không ở cơ sở dữ liệu: mọi bảng nghiệp vụ có `org_id`, mọi repository nhận `org_id` từ token và tự thêm điều kiện lọc vào câu SQL. Bản ghi của tổ chức khác trả `404`, không bao giờ trả `403`.

---

## Mức 3 — Thành phần bên trong API

### 3.1 Bản đồ module

API là một **modular monolith**: một tiến trình, chia thành 14 module có ranh giới cứng. Mũi tên `A → B` nghĩa là A đọc hoặc ghi dữ liệu của B **qua interface của B**, không bao giờ query thẳng vào bảng của B. Sơ đồ lấy bằng cách quét import trong `repository/acl` của từng module trên `main` ngày 13/10/2026; `tests/test_architecture.py` kiểm các luật này, kể cả "không có vòng phụ thuộc".

```mermaid
flowchart LR
    subgraph admin["Quản trị"]
        iam["<b>iam</b> ✅<br/>đăng nhập, token"]
        rules["<b>rules</b> ✅<br/>cấu hình theo tổ chức,<br/>danh mục mã ngoại lệ"]
        audit["<b>audit</b> ✅<br/>nhật ký chỉ-thêm"]
    end

    subgraph master["Danh mục"]
        vendor["<b>vendor</b> ✅<br/>nhà cung cấp, quy tắc nhớ"]
        procurement["<b>procurement</b> ✅<br/>PO, phiếu nhập,<br/>số lượng lũy kế"]
        erp["<b>erp</b> ◐<br/>kéo feed ERP"]
    end

    subgraph intake["Tiếp nhận"]
        invoice["<b>invoice</b> ✅<br/>tải lên, lô, trạng thái,<br/>sửa trường"]
        extraction["<b>extraction</b> ✅<br/>XML, PDF text, ảnh"]
    end

    subgraph match["Đối chiếu"]
        reconciliation["<b>reconciliation</b> ✅<br/>truy hồi, khớp dòng,<br/>kiểm tra, phân loại"]
    end

    subgraph after["Sau đối chiếu"]
        approval["<b>approval</b> ◐<br/>duyệt cấp 1, cấp 2"]
        export["<b>export</b> ✅<br/>xuất Excel / CSV"]
        reporting["<b>reporting</b> ✅<br/>danh sách, tổng quan,<br/>điểm sẵn sàng NCC"]
    end

    subgraph aimods["AI"]
        gateway["<b>gateway</b> ◐<br/>OpenRouter, ngân sách,<br/>cache, chi phí"]
        semantic["<b>semantic</b> ⬜<br/>tìm theo vector"]
    end

    invoice --> extraction --> gateway
    extraction --> rules
    gateway --> rules
    semantic --> gateway
    invoice --> rules & vendor
    procurement --> vendor
    erp --> invoice & procurement & vendor
    reconciliation --> invoice & procurement & vendor & rules & gateway
    approval --> invoice & reconciliation & procurement & rules & vendor
    export --> approval & iam & invoice & procurement & reconciliation & vendor
    reporting --> invoice & reconciliation & approval & vendor

    classDef done fill:#438dd5,color:#fff,stroke:#2e6295
    classDef wip fill:#f0ad4e,color:#000,stroke:#b7832f
    classDef todo fill:#999,color:#fff,stroke:#6b6b6b
    class iam,rules,audit,vendor,procurement,invoice,extraction,reconciliation,export,reporting done
    class erp,approval,gateway wip
    class semantic todo
```

*Ký hiệu theo `P-143/src/module/ENTITIES.md`: ✅ đủ các tầng; ◐ thiếu một phần implement; ⬜ mới có domain và interface. Không vẽ mũi tên tới `audit`: mọi module có ghi dữ liệu đều ghi nhật ký qua `audit` trong cùng transaction. `src/app` (wiring, đồ thị LangGraph, worker) biết mọi module; không module nào biết `app`.*

### 3.2 Từng module làm gì

| Module | Trách nhiệm | Bảng sở hữu | Endpoint chính | Trạng thái |
|---|---|---|---|:-:|
| **iam** | Đăng nhập, cấp và thu hồi token, khóa tài khoản sau 5 lần sai | `orgs`, `users`, `sessions`, `revoked_access_tokens`, `login_attempts` | `/auth/*` | ✅ |
| **audit** | Ghi nhật ký cho mọi module, lọc và xuất cho kiểm toán | `audit_logs` (chỉ `INSERT`, `SELECT`) | `/admin/audit-logs*`, `/exports/audit` | ✅ |
| **rules** | Cấu hình theo tổ chức (YAML + bản mới nhất trong DB, có cache), danh mục mã ngoại lệ, đọc tiền bằng chữ | `config_versions` | `/admin/config*` | ✅ |
| **vendor** | Nhà cung cấp, quy tắc nhớ (tên hàng, quy đổi đơn vị, dung sai riêng), học alias từ lần gán tay, tài khoản ngân hàng đã xác minh | `vendors`, `vendor_rules` | `/vendors*` | ✅ |
| **procurement** | Nhập PO và phiếu nhập từ Excel / CSV / JSON / MISA AMIS; sổ số lượng đã nhận và đã hóa đơn theo dòng PO | `purchase_orders`, `po_lines`, `goods_receipts`, `grn_lines`, `po_line_invoicings` | `/purchase-orders*`, `/goods-receipts*` | ✅ |
| **erp** | Kéo PO, phiếu nhập, file hóa đơn từ feed ERP theo con trỏ; lưu mỗi lần đồng bộ | `sync_runs` | `/erp/sync`, `/erp/sync-runs` | ◐ chưa đẩy ngược sang ERP |
| **invoice** | Tải lên (thường và qua URL ký sẵn), lô, chống trùng theo `sha256`, máy trạng thái hóa đơn, ghi kết quả trích xuất, sửa và xác nhận trường | `files`, `upload_sessions`, `upload_batches`, `invoices`, `invoice_lines`, `extraction_fields` | `/invoices/upload*`, `/invoices/batches*`, `/invoices/{id}`, `…/fields*`, `…/reading*`, `…/reprocess` | ✅ |
| **extraction** | Chọn cách đọc rẻ nhất: XML TT78 → PDF có text → ảnh (`OCR_MODE` graph hoặc demo) | — | — | ✅ |
| **reconciliation** | Truy hồi PO (bậc 1–2, B1 / B2 theo cờ), khớp dòng theo `matching.yaml`, kiểm dung sai, thuế, toàn vẹn, phân loại; xử lý ngoại lệ; gán PO và gán dòng bằng tay | `invoice_po_links`, `line_matches`, `line_match_overrides`, `discrepancies`, `invoice_tax_assessments` | `…/comparison`, `…/discrepancies`, `/discrepancies/{id}/resolve`, `…/relink-po`, `…/lines/{line_id}/match`, `/reconciliation/invoices/{id}/run` | ✅ |
| **approval** | Duyệt, từ chối, trả lại; quyết định có cần cấp 2; tách quyền; ghi số lượng đã hóa đơn khi duyệt xong | `approvals` | `…/approve`, `…/reject`, `…/return`, `/approvals/queue` | ◐ |
| **export** | Xuất hóa đơn đã duyệt và báo cáo đối soát ra Excel / CSV; hóa đơn đã xuất chuyển `EXPORTED`. Không sinh bút toán | — (chỉ đọc) | `/exports/*` | ✅ |
| **reporting** | Danh sách công việc, tổng quan, điểm sẵn sàng tự động hóa của NCC, chi phí | — (chỉ đọc) | `GET /invoices`, `/dashboard/summary`, `/vendors/{id}/readiness`, `/admin/costs` | ✅ |
| **gateway** | Cổng duy nhất ra dịch vụ AI qua OpenRouter: mô hình chữ có structured output, mô hình đọc ảnh; kiểm ngân sách ngày, cache, ghi chi phí | `ai_calls`, `ai_cache` | — | ◐ chưa có `Embedder` |
| **semantic** | Tìm PO theo vector (truy hồi bậc 3) | `embeddings` | — | ⬜ |

*Module `ledger` (bút toán) có ở bản 23/09 đã bị bỏ ngày 02/10/2026 (migration `0012_drop_journal`): trạng thái `POSTED` thành `EXPORTED`, bảng `journal_entries`, `journal_lines` bị xóa.*

### 3.3 Một hóa đơn đi qua các module thế nào

```mermaid
sequenceDiagram
    autonumber
    actor KTV as Kế toán viên
    participant INV as invoice
    participant ST as Kho file gốc
    participant G as app.graph (LangGraph)
    participant EX as extraction
    participant REC as reconciliation
    participant APR as approval
    participant EXP as export

    KTV->>INV: POST /invoices/upload (nhiều file)
    INV->>ST: lưu file theo org_id/sha256
    INV->>INV: tạo hóa đơn UPLOADED trong một lô
    INV->>G: mở thread cho từng hóa đơn
    INV-->>KTV: 202 + batch_id

    G->>EX: trích xuất (XML trước, rồi PDF text, rồi ảnh)
    EX-->>INV: trường + confidence + bằng chứng → EXTRACTED
    opt READING_REVIEW bật, hoặc hóa đơn chỉ đọc từ ảnh
        G-->>KTV: dừng ở chỗ đọc: GET /invoices/{id}/reading
        KTV->>INV: xác nhận hoặc sửa trường, POST …/reading/complete
    end

    G->>REC: đối chiếu: truy hồi PO / GRN → khớp dòng → kiểm tra → phân loại 🟢🟡🔴
    REC->>INV: → MATCHED → PENDING_L1

    KTV->>REC: sửa trường, gán PO, gán dòng, xử lý ngoại lệ (đối chiếu lại ngay)
    KTV->>APR: POST /invoices/{id}/approve
    APR->>APR: cần cấp 2? (ngưỡng tiền, NCC mới, lệch được chấp nhận, cờ gian lận)
    APR->>INV: → APPROVED (hoặc PENDING_L2, KTT khác người cấp 1 duyệt)
    KTV->>EXP: POST /exports/approved-invoices
    EXP->>INV: → EXPORTED
```

---

## Mức 4 — Code

> Mức này viết theo code ngày 23/09/2026. Cách tổ chức một module và lớp `reconciliation` vẫn đúng; tên và số service đã đổi nhiều. Bản mới nhất của từng module: `P-143/src/module/<module>/README.md`.

### 4.1 Giải phẫu một module

Mọi module theo cùng một khuôn. Ví dụ dưới đây dùng tên thật của `reconciliation`.

```
src/module/reconciliation/
├── domain/                 entity, view, enum, và các hàm thuần (checks/, matching/, retrieval/)
│   └── contracts/          chỉ có interface (typing.Protocol)
│       ├── repository.py   bảng của chính module — nội bộ
│       ├── provided.py     module cung cấp cho module khác — đọc/ghi theo lô
│       ├── required.py     module cần từ bên ngoài — do chính module định nghĩa
│       └── service.py      use case
├── dto/                    dữ liệu đi qua ranh giới: HTTP, giữa các module
├── repository/
│   ├── postgres/           cài đặt repository.py bằng SQL thuần
│   └── acl/                cài đặt required.py bằng provided.py của module khác
├── service/                cài đặt service.py, chỉ phụ thuộc interface
└── handler/                FastAPI router
```

```mermaid
flowchart LR
    handler["handler<br/><i>router</i>"] --> svc_c["contracts/service.py"]
    service["service"] -. "cài đặt" .-> svc_c
    service --> req["contracts/required.py"]
    service --> repo_c["contracts/repository.py"]
    service --> domain["domain<br/><i>hàm thuần</i>"]
    pg["repository/postgres"] -. "cài đặt" .-> repo_c
    acl["repository/acl"] -. "cài đặt" .-> req
    acl --> other["provided.py<br/>của module khác"]
    wiring["app/wiring.py"] -. "ráp tất cả" .-> service & pg & acl

    classDef iface fill:#fff,color:#000,stroke:#333,stroke-dasharray: 4 3
    class svc_c,req,repo_c,other iface
```

**Luật import** (kiểm tự động bằng `tests/test_architecture.py`):

- `service` không bao giờ import `repository`. Nó chỉ biết interface.
- Chỉ `repository/acl` được import module khác, và chỉ được import `domain` hoặc `dto` của module đó.
- Không có vòng phụ thuộc giữa các module.
- Entity chỉ giữ **id** của module khác, không giữ object. Đọc chéo luôn theo lô (`= ANY(%(ids)s)`), không có vòng lặp N+1.

**Transaction:** `TenantUnitOfWork` mở **một** transaction cho **một** tổ chức. Composition root gắn repository của module *và* các adapter `acl` sang module khác vào **cùng một connection**. Ví dụ: `reconciliation` ghi kết quả đối chiếu và chuyển trạng thái hóa đơn (bảng của `invoice`) trong cùng một lần commit.

### 4.2 Sơ đồ lớp của `reconciliation`

```mermaid
classDiagram
    direction LR

    class ReconcileInvoice {
        <<interface>>
        +run(ctx, invoice_id) ReconciliationResult
    }
    class ReconcileInvoiceService {
        -uow: ReconciliationUnitOfWork
        -policies: PolicyResolver
        -words: AmountSpeller
        -matching: LineMatching
        -clock: Clock
        +run(ctx, invoice_id)
    }
    ReconcileInvoiceService ..|> ReconcileInvoice

    class DocumentRetrieval {
        <<interface>>
        +retrieve(side, vendor_id, tol, book) RetrievalResult
    }
    class TieredDocumentRetrieval {
        bậc 1: số đơn đặt hàng
        bậc 2: mã số thuế + khoảng ngày
        bậc 3: vector ⏳
    }
    TieredDocumentRetrieval ..|> DocumentRetrieval

    class LineMatching {
        <<interface>>
        +match_all(side, procurement, vendor, tol)
    }
    class LadderLineMatching {
        L0 mã hàng · L1 quy tắc nhớ
        L2 chuẩn hóa · L3 so chuỗi mờ
        -arbiter: LineMatchArbiter
    }
    LadderLineMatching ..|> LineMatching

    class LineMatchArbiter {
        <<interface>>
        +choose(line, candidates) ArbiterVerdict
    }
    class InconclusiveArbiter {
        luôn từ chối → L5
    }
    class LlmArbiter {
        ⏳ L4 qua gateway.StructuredLlm
    }
    InconclusiveArbiter ..|> LineMatchArbiter
    LlmArbiter ..|> LineMatchArbiter
    LadderLineMatching --> LineMatchArbiter

    class ReconciliationUnitOfWork {
        <<interface>>
        +begin(org_id) ReconciliationTransaction
    }
    class ReconciliationTransaction {
        <<interface>>
        invoices: InvoiceSource
        procurement: ProcurementSource
        vendors: VendorSource
        status: InvoiceStatusSink
        links, matches, discrepancies
    }
    class PostgresReconciliationUnitOfWork
    PostgresReconciliationUnitOfWork ..|> ReconciliationUnitOfWork
    ReconciliationUnitOfWork --> ReconciliationTransaction

    class InvoiceSourceAdapter {
        acl → invoice
    }
    class ProcurementSourceAdapter {
        acl → procurement
    }
    class VendorSourceAdapter {
        acl → vendor
    }
    class TenantPolicyResolver {
        acl → rules
    }
    ReconciliationTransaction --> InvoiceSourceAdapter
    ReconciliationTransaction --> ProcurementSourceAdapter
    ReconciliationTransaction --> VendorSourceAdapter

    class run_checks {
        <<hàm thuần>>
        integrity · tolerance · tax · lines
    }
    class classify {
        <<hàm thuần>>
        BLOCK → RED · REVIEW → YELLOW · còn lại GREEN
    }

    ReconcileInvoiceService --> ReconciliationUnitOfWork
    ReconcileInvoiceService --> TieredDocumentRetrieval
    ReconcileInvoiceService --> LineMatching
    ReconcileInvoiceService --> TenantPolicyResolver
    ReconcileInvoiceService --> run_checks
    ReconcileInvoiceService --> classify
```

### 4.3 Một lần `ReconcileInvoiceService.run`

Toàn bộ chạy trong **một transaction**, với **số câu query cố định** bất kể hóa đơn có bao nhiêu dòng. Mọi kiểm tra là hàm thuần trên dữ liệu đã nạp sẵn. **Không có LLM trên đường này.**

```mermaid
sequenceDiagram
    autonumber
    participant S as ReconcileInvoiceService
    participant R as rules (qua acl)
    participant TX as ReconciliationTransaction
    participant RT as TieredDocumentRetrieval
    participant LM as LadderLineMatching
    participant CK as run_checks / classify

    S->>R: for_tenant(org_id) → dung sai, thuế suất, danh mục mã ngoại lệ
    S->>TX: begin(org_id)
    TX->>TX: invoices.load(id) — hóa đơn, dòng, confidence
    TX->>TX: vendors.load(mã số thuế) — nhà cung cấp + quy tắc nhớ ACTIVE
    alt đã gán đơn đặt hàng thủ công
        TX->>TX: dùng liên kết MANUAL
    else
        S->>RT: retrieve — bậc 1, rồi bậc 2
    end
    TX->>TX: procurement.load(po_ids) — đơn, dòng, phiếu nhập kho
    S->>S: chia phiếu nhập kho theo cửa sổ ngày
    S->>LM: match_all — thang L0 → L3, L4 qua arbiter
    S->>CK: run_checks(ReconciliationContext)
    CK-->>S: danh sách ngoại lệ (mã, mức, công thức, bằng chứng)
    S->>CK: classify → GREEN / YELLOW / RED
    S->>TX: giữ ngoại lệ đã xử lý, thay ngoại lệ đang mở
    S->>TX: ghi links, line_matches, discrepancies
    S->>TX: status.mark_matched → MATCHED
    TX-->>S: commit
```

### 4.4 Chỗ cắm AI vào sau này

Mọi điểm dùng AI đều là **một interface đã có sẵn**. Cài đặt thật chỉ cần thêm một class và đăng ký trong `src/app/wiring.py`, không phải sửa lõi.

| Điểm cắm | Interface | Hiện tại | Sẽ là | Yêu cầu |
|---|---|---|---|---|
| Đọc file | `extraction.InvoiceExtractor` (danh sách strategy trong `StrategyExtractionRouter`) | `XmlInvoiceExtractor` | + `PdfTextExtractor`, `OcrExtractor` qua `gateway` | F2.3, F2.8 |
| Khớp tên hàng khó | `reconciliation.LineMatchArbiter` | `InconclusiveArbiter` (luôn từ chối) | `LlmArbiter`, chỉ được chọn trong danh sách ứng viên | F5.1, F5.2 |
| Câu giải thích | `Discrepancy.explanation` | `None` | Bộ viết giải thích, chạy sau khi mã và số tiền đã chốt | F9.2, F9.3 |
| Tìm chứng từ bằng vector | `semantic.SemanticIndex` | chưa nối | Chỉ đề xuất ứng viên, luôn để người chọn | F4.3 |
| Gọi dịch vụ AI | `gateway.StructuredLlm`, `OcrEngine`, `Embedder`, `BudgetGuard` | chỉ có interface | OpenAI, Document AI; ghi `ai_calls`, cache `ai_cache` | F2.9, F2.10, F16 |
| Điều phối | `invoice.ProcessingQueue`, `reconciliation.FollowUpQueue` | `InProcessPipeline` | LangGraph + Postgres checkpointer, chờ duyệt bằng `interrupt` | F11.6 |
| Phần mềm kế toán | `erp.ErpConnector` | chỉ có interface | `SeedConnector`, `ExcelCsvConnector`, sau này `MisaConnector` | F17 |

---

## Phụ lục — Những điểm đang lệch so với PRD

| Điểm | PRD | Code hiện tại | Ảnh hưởng |
|---|---|---|---|
| Điều phối | LangGraph, chờ duyệt sống qua khởi động lại (F11.6) | `asyncio` task trong tiến trình | Khởi động lại khi đang xử lý thì hóa đơn kẹt ở `UPLOADED` / `EXTRACTED`, phải bấm xử lý lại |
| Trích xuất | XML, PDF có chữ, ảnh | Chỉ XML | PDF và ảnh vào trạng thái `FAILED` với `UNSUPPORTED_FORMAT` |
| Khớp dòng L4 | LLM chọn ứng viên | Luôn từ chối | Dòng rơi vào vùng so chuỗi mờ 75–92 điểm thành "không khớp được" |
| Tìm bậc 3 | Vector | Chưa nối | Trượt bậc 2 thì báo "không tìm thấy đơn đặt hàng" |
| Kiểm gian lận | F8 | Chưa có bước `fraud_check`. Đã có: trùng tuyệt đối chặn bằng unique index; nhà cung cấp mới buộc duyệt cấp 2 (trong `approval`) | Chưa có cảnh báo gần trùng, tách nhỏ, đổi tài khoản, giá vượt lịch sử |
| Email người dùng | Duy nhất trong tổ chức | Duy nhất toàn hệ thống | Đăng nhập không cần chọn tổ chức |
