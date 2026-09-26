# Thiết kế C4 — Invoice Reconciliation Agent

> Kiến trúc hệ thống theo mô hình C4, từ tổng quan tới code · Ngày 23/09/2026
> Vẽ theo code thật ở repo `P-143` (nhánh `feat/module-api`), không theo ý định trên giấy
> Tài liệu liên quan: `PRD.md` (yêu cầu) · `USER_STORIES.md` (tình huống nghiệp vụ) · `P-143/src/module/README.md` (quy tắc module)

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
    ktv["👤 Kế toán viên<br/><i>Tải hóa đơn lên, xử lý chỗ lệch,<br/>duyệt cấp 1, xuất bút toán</i>"]
    ktt["👤 Kế toán trưởng<br/><i>Duyệt cấp 2, cấu hình dung sai,<br/>duyệt quy tắc nhà cung cấp, xem nhật ký</i>"]

    sys["<b>Hệ thống đối soát hóa đơn</b><br/><i>Đọc hóa đơn, tìm đơn đặt hàng và phiếu nhập kho,<br/>đối chiếu từng dòng, phân loại chỗ lệch,<br/>đề xuất cách xử lý, sinh bút toán</i>"]

    ncc["🏢 Nhà cung cấp<br/><i>Gửi hóa đơn điện tử qua email</i>"]
    mh["🏢 Phòng mua hàng và kho<br/><i>Xuất file Excel đơn đặt hàng,<br/>phiếu nhập kho</i>"]
    pmkt["🖥 Phần mềm kế toán<br/><i>MISA, Fast… — nhận file bút toán</i>"]
    ai["☁️ Dịch vụ AI<br/><i>OpenAI: LLM, embedding<br/>Google Document AI: đọc ảnh</i>"]
    thue["☁️ Tra cứu mã số thuế<br/><i>Giả lập trong bản MVP</i>"]

    ncc -. "hóa đơn XML / PDF / ảnh<br/>(kế toán viên nhận rồi tải lên)" .-> ktv
    mh -. "file Excel<br/>(kế toán viên nhập vào)" .-> ktv
    ktv -- "tải hóa đơn, nhập chứng từ,<br/>đối soát, duyệt" --> sys
    ktt -- "duyệt cấp 2, cấu hình,<br/>tra nhật ký" --> sys
    sys -- "file bút toán Excel / CSV" --> pmkt
    sys -- "đọc chữ, xếp trường,<br/>khớp tên hàng khó, viết giải thích" --> ai
    sys -- "mã số thuế còn hoạt động?" --> thue

    classDef person fill:#08427b,color:#fff,stroke:#052e56
    classDef system fill:#1168bd,color:#fff,stroke:#0b4884
    classDef external fill:#999,color:#fff,stroke:#6b6b6b
    class ktv,ktt person
    class sys system
    class ncc,mh,pmkt,ai,thue external
```

**Ranh giới cần nhớ**

- Hệ thống **không nhận email trực tiếp** từ nhà cung cấp, và **không kết nối thẳng** với phần mềm kế toán ở bản MVP. Mọi thứ đi vào qua tay kế toán viên, đi ra dưới dạng file.
- Hệ thống **không thanh toán**. Nó chỉ đưa hóa đơn tới trạng thái "đã chốt bút toán".
- Dịch vụ AI chỉ được gọi ở 3 chỗ: đọc hóa đơn không phải XML, khớp tên hàng khó, viết câu giải thích. **Không có con số nào do AI quyết.**

---

## Mức 2 — Các khối triển khai

```mermaid
flowchart TB
    ktv["👤 Kế toán viên"]
    ktt["👤 Kế toán trưởng"]

    subgraph sys["Hệ thống đối soát hóa đơn"]
        web["<b>Ứng dụng web</b> ⏳<br/><i>HTML + JavaScript thuần, không cần build</i><br/>Danh sách hóa đơn, màn so sánh 3 chiều,<br/>hàng đợi duyệt, cấu hình"]
        api["<b>API</b> ✅<br/><i>Python 3.11, FastAPI, uvicorn</i><br/>Toàn bộ nghiệp vụ, REST /api/v1,<br/>xác thực JWT, phân quyền"]
        pipe["<b>Pipeline xử lý nền</b> 🚧<br/><i>InProcessPipeline, chạy chung tiến trình API</i><br/>trích xuất → đối chiếu → chờ duyệt<br/><i>Sẽ thay bằng LangGraph</i>"]
        db[("<b>Cơ sở dữ liệu</b> ✅<br/><i>PostgreSQL 18 + pgvector</i><br/>Dữ liệu nghiệp vụ mọi tổ chức,<br/>nhật ký, cấu hình theo phiên bản")]
        files[("<b>Kho file gốc</b> ✅<br/><i>Ổ đĩa cục bộ hoặc S3 / MinIO</i><br/>khóa org_id/sha256")]
        yaml["<b>Cấu hình mặc định</b> ✅<br/><i>config/*.yaml, đóng gói cùng API</i><br/>dung sai, thuế suất, ngưỡng duyệt,<br/>giới hạn, sơ đồ tài khoản"]
    end

    openai["☁️ OpenAI ⏳<br/><i>LLM gpt-4o-mini, embedding</i>"]
    docai["☁️ Google Document AI ⏳"]
    langsmith["☁️ LangSmith ⏳<br/><i>theo dõi và đo chi phí</i>"]

    ktv & ktt -- "HTTPS" --> web
    web -- "REST + JSON, Bearer JWT" --> api
    api -- "xếp hóa đơn vào hàng đợi" --> pipe
    api -- "SQL, psycopg 3 async" --> db
    pipe -- "SQL" --> db
    api -- "ghi / đọc file" --> files
    pipe -- "đọc file" --> files
    api -- "đọc lúc khởi động" --> yaml
    pipe -. "qua module gateway" .-> openai & docai
    pipe -. "trace" .-> langsmith

    classDef person fill:#08427b,color:#fff,stroke:#052e56
    classDef container fill:#438dd5,color:#fff,stroke:#2e6295
    classDef external fill:#999,color:#fff,stroke:#6b6b6b
    class ktv,ktt person
    class web,api,pipe,db,files,yaml container
    class openai,docai,langsmith external
```

| Khối | Công nghệ | Trạng thái | Ghi chú |
|---|---|:-:|---|
| Ứng dụng web | HTML + JavaScript thuần, không cần build | ⏳ | Chưa có trong repo `P-143`. Đi tiếp từ `docs/prototype/`, hiện chạy trên dữ liệu mẫu. Màn hình theo `WIREFRAME.md` |
| API | FastAPI, uvicorn, psycopg 3 async, SQL thuần, không ORM | ✅ | Mọi endpoint ở `PRD.md` mục 8. Swagger tại `/docs` |
| Pipeline xử lý nền | `asyncio` task trong cùng tiến trình | 🚧 | `PIPELINE_MODE=background` cho API, `inline` cho test, `off` để giao cho worker riêng sau này. Chưa có LangGraph, chưa có checkpointer, nên hóa đơn đang chạy dở sẽ mất nếu khởi động lại |
| Cơ sở dữ liệu | PostgreSQL 18 (dùng `uuidv7()` sẵn có), pgvector | ✅ | Migration SQL thuần ở `migrations/`, mỗi file có checksum |
| Kho file gốc | `STORAGE_BACKEND=local` hoặc `s3` | ✅ | MinIO khi chạy cục bộ. Trùng `sha256` trong cùng tổ chức thì không lưu lại |
| Cấu hình mặc định | YAML | ✅ | Kế toán trưởng sửa qua API thì lưu thành bản mới ở bảng `config_versions`, đè lên YAML. File YAML hỏng thì API không khởi động |

**Chạy cục bộ:** `docker compose` gồm `db`, `minio`, `minio-init`, `backend`. **Triển khai:** Render (Web Service cho API, Static Site cho web, PostgreSQL) theo `BRIEF_v3.md`.

**Đa tổ chức** được đảm bảo ở khối API, không ở cơ sở dữ liệu: mọi bảng nghiệp vụ có `org_id`, mọi repository nhận `org_id` từ token và tự thêm điều kiện lọc vào câu SQL. Bản ghi của tổ chức khác trả `404`, không bao giờ trả `403`.

---

## Mức 3 — Thành phần bên trong API

### 3.1 Bản đồ module

API là một **modular monolith**: một tiến trình, chia thành các module có ranh giới cứng. Mũi tên `A → B` nghĩa là A đọc hoặc ghi dữ liệu của B **qua interface của B**, không bao giờ query thẳng vào bảng của B.

```mermaid
flowchart LR
    subgraph platform["Nền tảng"]
        core["<b>core</b><br/>DB pool, unit of work theo tổ chức,<br/>bảo mật, tiền Decimal, lỗi"]
        app["<b>app</b><br/>wiring: ráp mọi module<br/>pipeline: chạy nền"]
    end

    subgraph admin["Quản trị"]
        iam["<b>iam</b> ✅<br/>đăng nhập, token, khóa tài khoản"]
        rules["<b>rules</b> ✅<br/>cấu hình theo tổ chức,<br/>danh mục mã ngoại lệ, tiền bằng chữ"]
        audit["<b>audit</b> ✅<br/>nhật ký chỉ-thêm"]
    end

    subgraph master["Danh mục"]
        vendor["<b>vendor</b> ✅<br/>nhà cung cấp, quy tắc nhớ"]
        procurement["<b>procurement</b> ✅<br/>đơn đặt hàng, phiếu nhập kho,<br/>số lượng đã hóa đơn"]
        erp["<b>erp</b> 🚧<br/>cổng phần mềm kế toán"]
    end

    subgraph intake["Tiếp nhận"]
        invoice["<b>invoice</b> ✅<br/>tải lên, trạng thái, sửa trường"]
        extraction["<b>extraction</b> 🚧<br/>đọc file thành trường<br/>(mới có XML)"]
    end

    subgraph match["Đối chiếu"]
        reconciliation["<b>reconciliation</b> ✅<br/>tìm chứng từ, khớp dòng,<br/>kiểm tra, phân loại"]
    end

    subgraph after["Sau đối chiếu"]
        approval["<b>approval</b> ✅<br/>duyệt cấp 1, cấp 2"]
        ledger["<b>ledger</b> ✅<br/>bút toán, xuất file"]
        reporting["<b>reporting</b> ✅<br/>danh sách, tổng quan,<br/>điểm sẵn sàng nhà cung cấp"]
    end

    subgraph aimods["AI"]
        gateway["<b>gateway</b> 🚧<br/>LLM, OCR, embedding,<br/>ngân sách, cache"]
        semantic["<b>semantic</b> 🚧<br/>tìm theo vector"]
    end

    invoice --> extraction --> gateway
    semantic --> gateway
    invoice --> rules & vendor
    procurement --> vendor
    erp --> procurement & vendor
    reconciliation --> invoice & procurement & vendor & rules
    approval --> invoice & reconciliation & procurement & ledger & rules & vendor
    ledger --> invoice & reconciliation & procurement & rules & vendor
    reporting --> invoice & reconciliation & approval & vendor

    classDef done fill:#438dd5,color:#fff,stroke:#2e6295
    classDef wip fill:#f0ad4e,color:#000,stroke:#b7832f
    classDef base fill:#6c757d,color:#fff,stroke:#495057
    class iam,rules,audit,vendor,procurement,invoice,reconciliation,approval,ledger,reporting done
    class erp,extraction,gateway,semantic wip
    class core,app base
```

*Không vẽ các mũi tên tới `audit` cho đỡ rối: mọi module có ghi dữ liệu đều ghi nhật ký qua `audit` trong cùng transaction. Không vẽ mũi tên tới `core`: mọi module đều dùng nó. `app` biết mọi module; không module nào biết `app`.*

### 3.2 Từng module làm gì

| Module | Trách nhiệm | Bảng sở hữu | Endpoint chính | Trạng thái |
|---|---|---|---|:-:|
| **iam** | Đăng nhập, cấp và thu hồi token, khóa tài khoản sau 5 lần sai | `orgs`, `users`, `sessions`, `revoked_access_tokens`, `login_attempts` | `/auth/*` | ✅ |
| **audit** | Ghi nhật ký cho mọi module, lọc và xuất cho kiểm toán | `audit_logs` (chỉ `INSERT`, `SELECT`) | `/admin/audit-logs`, `/exports/audit` | ✅ |
| **rules** | Cấu hình theo tổ chức (YAML + bản mới nhất trong DB, có cache), danh mục mã ngoại lệ, đọc tiền bằng chữ | `config_versions` | `/admin/config*` | ✅ |
| **vendor** | Nhà cung cấp, quy tắc nhớ (tên hàng, quy đổi đơn vị, dung sai riêng) | `vendors`, `vendor_rules` | `/vendors*` | ✅ |
| **procurement** | Nhập đơn đặt hàng và phiếu nhập kho từ Excel/CSV; sổ số lượng đã hóa đơn theo từng dòng đơn đặt hàng | `purchase_orders`, `po_lines`, `goods_receipts`, `grn_lines`, `po_line_invoicings` | `/purchase-orders*`, `/goods-receipts/import` | ✅ |
| **erp** | Interface `ErpConnector` để sau này nối MISA | `sync_runs` | — | 🚧 |
| **invoice** | Tải lên, chống trùng theo `sha256`, lưu file, máy trạng thái hóa đơn, ghi kết quả trích xuất, sửa trường | `files`, `upload_batches`, `invoices`, `invoice_lines`, `extraction_fields` | `/invoices/upload`, `/invoices/{id}`, `PATCH …/fields`, `…/reprocess`, `…/file` | ✅ |
| **extraction** | Chọn cách đọc rẻ nhất cho từng file | — | — | 🚧 mới có XML |
| **reconciliation** | Tìm chứng từ, khớp dòng, kiểm dung sai, thuế, toàn vẹn, phân loại; xử lý ngoại lệ; gán lại đơn đặt hàng thủ công | `invoice_po_links`, `line_matches`, `discrepancies` | `…/comparison`, `…/discrepancies`, `/discrepancies/{id}/resolve`, `…/relink-po` | ✅ không LLM |
| **approval** | Duyệt, từ chối, trả lại; quyết định có cần cấp 2; ghi số lượng đã hóa đơn khi duyệt xong | `approvals` | `…/approve`, `…/reject`, `…/return`, `/approvals/queue` | ✅ |
| **ledger** | Sinh bút toán đề xuất, sửa tài khoản, xuất file (xuất là bước chốt: `APPROVED → POSTED`) | `journal_entries`, `journal_lines` | `…/journal`, `/exports/journal` | ✅ |
| **reporting** | Danh sách công việc, tổng quan, điểm sẵn sàng tự động hóa của nhà cung cấp, chi phí, báo cáo đối soát | — (chỉ đọc qua module khác) | `GET /invoices`, `/dashboard/summary`, `/vendors/{id}/readiness`, `/admin/costs`, `/exports/reconciliation` | ✅ |
| **gateway** | Cổng duy nhất ra dịch vụ AI: `StructuredLlm`, `OcrEngine`, `Embedder`, `BudgetGuard`; ghi chi phí, cache | `ai_calls`, `ai_cache` | — | 🚧 chỉ có interface |
| **semantic** | `SemanticIndex`: đánh chỉ mục và tìm theo vector | `embeddings` | — | 🚧 chỉ có interface |

### 3.3 Một hóa đơn đi qua các module thế nào

```mermaid
sequenceDiagram
    autonumber
    actor KTV as Kế toán viên
    participant INV as invoice
    participant ST as Kho file gốc
    participant P as app.pipeline
    participant EX as extraction
    participant REC as reconciliation
    participant APR as approval
    participant LED as ledger

    KTV->>INV: POST /invoices/upload (nhiều file)
    INV->>ST: lưu file theo org_id/sha256
    INV->>INV: tạo hóa đơn UPLOADED
    INV->>P: enqueue(ids)
    INV-->>KTV: 202 + batch_id

    P->>INV: InvoiceExtractionStep
    INV->>EX: StrategyExtractionRouter (XML trước, rồi PDF, rồi OCR)
    EX-->>INV: các trường + confidence + bằng chứng
    INV->>INV: ghi dòng, extraction_fields → EXTRACTED

    P->>REC: ReconcileInvoiceService.run
    REC->>REC: tìm chứng từ → khớp dòng → kiểm tra → phân loại 🟢🟡🔴
    REC->>INV: mark_matched → MATCHED
    P->>INV: → PENDING_L1

    KTV->>REC: POST /discrepancies/{id}/resolve (nếu có lệch)
    KTV->>APR: POST /invoices/{id}/approve
    APR->>APR: cần cấp 2? (ngưỡng tiền, lệch được chấp nhận, cờ gian lận)
    APR->>LED: soạn bút toán
    APR->>INV: → APPROVED (hoặc PENDING_L2)
    KTV->>LED: POST /exports/journal
    LED->>INV: → POSTED
```

---

## Mức 4 — Code

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
