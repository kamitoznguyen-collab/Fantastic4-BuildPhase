# Wireframe & UI Flow — Invoice Reconciliation Agent

> Luồng người dùng và phác thảo màn hình · Phiên bản 1.1 · Cập nhật 13/10/2026 (bản 1.0 ngày 20/09/2026)
> Bản 1.1 đối chiếu với giao diện thật ở `P-143/frontend` trên `main` tại `0ecb981` (10/10/2026): sửa sơ đồ trang (§2), thêm
> các màn hình S14–S17 (§5b), bổ sung bản đồ API (§9) và trạng thái từng màn hình (§10).
> Tài liệu liên quan: `BRIEF_v3.md` (định vị) · `PRD.md` (yêu cầu chức năng, mã ngoại lệ, API)
> Đối tượng đọc: người làm frontend, người chấm Demo Day

---

## 1. Nguyên tắc thiết kế

Năm nguyên tắc, xếp theo thứ tự ưu tiên khi phải đánh đổi.

1. **Giảm số lần phải chuyển ngữ cảnh.** Kế toán hiện phải mở ba file để so. Màn hình chính phải đặt hóa đơn, PO và phiếu nhập cạnh nhau, ngang hàng theo từng dòng.
2. **Mỗi con số phải chỉ được về nguồn.** Rê chuột vào bất kỳ giá trị nào thì thấy nó đến từ đâu: đường dẫn XML, trang và vùng ảnh, hay ai đã sửa tay.
3. **Nói lệch bao nhiêu, đừng chỉ nói "có lệch".** Mọi cảnh báo đi kèm số tiền và công thức.
4. **Không chắc thì phải trông khác đi.** Trường tin cậy thấp có dấu hiệu thị giác riêng, không lẫn với trường bình thường. Từ 07/10/2026 dấu hiệu đó là nhãn **"Cần xem"** (kèm lý do), trường không còn câu hỏi mang nhãn **"Đạt"**; giao diện **không hiện con số** độ tin cậy (PRD §1.3).
5. **Hành động nguy hiểm phải khó bấm nhầm.** Duyệt hóa đơn có ngoại lệ cần một bước xác nhận riêng nêu rõ đang chấp nhận lệch bao nhiêu tiền.

---

## 2. Sơ đồ trang

```
/login                              Đăng nhập

/                                   Tổng quan (mặc định sau khi đăng nhập)
/upload                             Tải hóa đơn lên, tiến độ, lịch sử tải lên
/batches                            Lô tải lên + trạng thái đồng bộ ERP         (S14)
/batches/:id                        Chi tiết một lô
/invoices                           Danh sách hóa đơn
/invoices/:id                       Chi tiết hóa đơn; các tab:
    ├── Nhập tay                      khi chưa trích xuất được              (S16)
    ├── Xem bản đọc (n)               khi đồ thị dừng ở chỗ đọc             (S15)
    ├── Chế độ thuế / Cơ sở giá       chỉ khi DOCUMENT_INTAKE bật           (S17)
    ├── So sánh 3 chiều               ← màn hình lõi                        (S5)
    ├── Ngoại lệ (n)                                                        (S6)
    ├── Tóm tắt duyệt                 (không có bút toán)                   (S7)
    └── Dòng thời gian                                                      (S12)
/files/:fileId                      Một PDF nhiều hóa đơn, xác nhận cách cắt   (chỉ DOCUMENT_INTAKE)
/approvals                          Hàng đợi chờ duyệt của tôi
/vendors                            Danh sách NCC + readiness score
/vendors/:id                        Chi tiết NCC: quy tắc memory + phân rã điểm
/documents                          Đơn hàng & phiếu nhập: danh sách, import    (S18)
/documents/:id                      Chi tiết một PO
/config                             Cấu hình ngưỡng           [chỉ KTT]
/audit                              Nhật ký kiểm toán         [chỉ KTT]
/costs                              Chi phí xử lý             [chỉ KTT]
```

Xuất dữ liệu không có trang riêng: là hộp thoại mở từ danh sách hóa đơn (`ExportDialog`).

Điều hướng chính đặt ở thanh bên trái, gom thành 3 nhóm: **Xử lý** (Tổng quan, Tải lên, Lô tải lên, Hóa đơn, Chờ duyệt) · **Dữ liệu** (Nhà cung cấp, Đơn hàng & phiếu nhập) · **Quản trị** (Cấu hình, Nhật ký, Chi phí — ẩn với KTV).

---

## 3. Luồng người dùng

### 3.1 Luồng chính — KTV xử lý hóa đơn hằng ngày

```mermaid
graph TD
    A[Đăng nhập] --> B[Dashboard:<br/>thấy 12 lệch, 8 cần kiểm tra]
    B --> C{Có file mới?}
    C -->|Có| D[Upload: kéo thả 15 file]
    D --> E[Theo dõi tiến độ lô]
    E --> F[Danh sách đã lọc theo lô]
    C -->|Không| F
    F --> G[Mở hóa đơn 🔴 tiền lớn nhất]
    G --> H[Tab So sánh 3 chiều]
    H --> I{Số liệu đọc có đúng không?}
    I -->|Sai| J[Sửa trường tại chỗ] --> K[Hệ thống chạy lại]
    K --> H
    I -->|Đúng| L[Tab Ngoại lệ]
    L --> M[Đọc giải thích + công thức]
    M --> N{Quyết định}
    N -->|Chấp nhận lệch| O[Chọn ACCEPT + lý do]
    N -->|Sai của NCC| P[REQUEST_CREDIT_NOTE]
    N -->|Chưa nhập đủ| Q[WAIT_GRN]
    N -->|Không hợp lệ| R[REJECT + lý do]
    O --> S[Xem tóm tắt duyệt]
    P --> T[Hóa đơn chờ NCC xử lý]
    Q --> T
    S --> U[Duyệt cấp 1]
    U --> V{Cần cấp 2?}
    V -->|Có| W[Chuyển hàng đợi KTT]
    V -->|Không| X[APPROVED → xuất kết quả]
    R --> Y[REJECTED]
```

### 3.2 Luồng KTT duyệt cấp 2

```mermaid
graph LR
    A[Hàng đợi chờ duyệt] --> B[Chỉ hiện HĐ mình<br/>chưa duyệt cấp 1]
    B --> C[Mở hóa đơn]
    C --> D[Xem: ai duyệt cấp 1,<br/>ngoại lệ nào được chấp nhận,<br/>lý do là gì]
    D --> E{Đồng ý?}
    E -->|Có| F[Duyệt cấp 2 → APPROVED]
    E -->|Cần sửa| G[Trả lại + lý do → RETURNED]
    E -->|Không| H[Từ chối + lý do → REJECTED]
```

### 3.3 Luồng sửa trường OCR (chi tiết vì đây là tương tác tinh tế nhất)

```mermaid
sequenceDiagram
    participant U as KTV
    participant UI as Giao diện
    participant API as FastAPI
    participant G as LangGraph

    U->>UI: Bấm vào ô "Đơn giá" có viền cảnh báo
    UI->>UI: Mở ô sửa tại chỗ, hiện ảnh gốc<br/>đã cuộn đến đúng vùng
    U->>UI: Gõ giá trị đúng, Enter
    UI->>API: PATCH /invoices/:id/fields
    API->>API: Ghi extraction_fields mới<br/>(bản cũ giữ nguyên, đánh superseded)
    API->>API: Ghi audit_logs
    API->>G: Chạy lại từ retrieve_docs
    API-->>UI: 202 + trạng thái PROCESSING
    UI->>UI: Hiện "Đang tính lại..." trên các vùng<br/>bị ảnh hưởng, giữ nguyên phần còn lại
    G-->>API: Kết quả mới
    API-->>UI: Phân loại mới + ngoại lệ mới
    UI->>UI: Cập nhật, làm nổi phần đã thay đổi
```

**Chi tiết dễ bị làm sai:** khi tính lại, **không** hiện spinner toàn trang. Chỉ vùng bị ảnh hưởng mờ đi. Kế toán đang đọc dở, làm mới cả trang là mất chỗ đang đọc.

---

## 4. Bản đồ trạng thái hóa đơn với giao diện

| Trạng thái | Hiển thị ở đâu | Nhãn tiếng Việt | Hành động khả dụng |
|---|---|---|---|
| `UPLOADED` | Trang upload | Đã tải lên | — |
| `QUEUED` | Trang upload | Đang chờ xử lý | Hủy |
| `EXTRACTED` | Danh sách | Đã đọc xong | Sửa trường, gán PO |
| `MATCHED` | Danh sách | Đã đối chiếu | Xử lý ngoại lệ |
| `PENDING_L1` | Danh sách + Chờ duyệt | Chờ duyệt cấp 1 | Duyệt, trả lại, từ chối |
| `PENDING_L2` | Chờ duyệt (KTT) | Chờ duyệt cấp 2 | Duyệt cấp 2, trả lại, từ chối |
| `APPROVED` | Danh sách | Sẵn sàng thanh toán | Xuất kết quả |
| `EXPORTED` | Danh sách | Đã xuất cho kế toán | Xem, xuất lại |
| `RETURNED` | Danh sách | Trả lại sửa | Sửa, gửi lại |
| `REJECTED` | Danh sách (lọc riêng) | Đã từ chối | Chỉ xem |
| `FAILED` | Danh sách (lọc riêng) | Xử lý lỗi | Xử lý lại, xóa |

---

## 5. Wireframe từng màn hình

Ký hiệu: `[ ]` nút · `▼` dropdown · `▸` mục mở rộng được · `◉` trạng thái đang chọn

### S1 — Đăng nhập

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│                    ┌────────────────────┐                    │
│                    │   [logo]           │                    │
│                    │   Đối soát hóa đơn │                    │
│                    └────────────────────┘                    │
│                                                              │
│              Email                                           │
│              ┌────────────────────────────────┐              │
│              │ ngoc.nguyen@xex.vn             │              │
│              └────────────────────────────────┘              │
│              Mật khẩu                                        │
│              ┌────────────────────────────────┐              │
│              │ ••••••••••••              👁   │              │
│              └────────────────────────────────┘              │
│                                                              │
│              [       Đăng nhập        ]                      │
│                                                              │
│              ⚠ Sai email hoặc mật khẩu.                      │
│                Còn 3 lần thử trước khi khóa 15 phút.         │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

Thông báo lỗi **không** được tiết lộ email có tồn tại hay không.

### S2 — Dashboard

```
┌────────────┬─────────────────────────────────────────────────────────────────┐
│ ĐỐI SOÁT   │  Tổng quan                          Ngọc (KTV) ▼   🌙   [Thoát] │
│            ├─────────────────────────────────────────────────────────────────┤
│ XỬ LÝ      │                                                                 │
│ ◉ Tổng quan│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐        │
│ ↑ Upload   │  │ 🟢 KHỚP   │ │🟡 CẦN XEM │ │ 🔴 LỆCH   │ │ CHỜ DUYỆT │        │
│ ▤ Hóa đơn  │  │           │ │           │ │           │ │           │        │
│ ✓ Chờ duyệt│  │    42     │ │     8     │ │    12     │ │    15     │        │
│   (15)     │  │ 486,2 tr  │ │  91,4 tr  │ │ 203,7 tr  │ │ 312,0 tr  │        │
│            │  │           │ │           │ │ lệch 8,4tr│ │           │        │
│ DỮ LIỆU    │  └───────────┘ └───────────┘ └───────────┘ └───────────┘        │
│ ⌂ Nhà CC   │     bấm để lọc     bấm để lọc    bấm để lọc    bấm để lọc       │
│ ▤ Đơn hàng │                                                                 │
│ ▤ Phiếu nhập│ ┌─────────────────────────────┐ ┌─────────────────────────────┐│
│            │  │ Cần xử lý trước              │ │ Ngoại lệ hay gặp tuần này  ││
│ QUẢN TRỊ   │  ├─────────────────────────────┤ ├─────────────────────────────┤│
│ ⚙ Cấu hình │  │🔴 HĐ 00012457 · Lốp Việt    │ │ PRC-01 Giá cao hơn PO   ▇▇▇9││
│ ▤ Nhật ký  │  │   48,5 tr · lệch 2,4 tr     │ │ QTY-01 HĐ > hàng nhận   ▇▇ 6││
│ ₫ Chi phí  │  │   PRC-01, TAX-02            │ │ INT-01 OCR tin cậy thấp ▇▇ 5││
│            │  │                              │ │ DOC-02 Thiếu phiếu nhập ▇  3││
│ ─────────  │  │🔴 HĐ 00012441 · Pin Minh Anh│ │ TAX-03 Lệch làm tròn    ▇  2││
│ v1.0       │  │   31,2 tr · lệch 1,1 tr     │ └─────────────────────────────┘│
│            │  │   QTY-01                     │                               │
│            │  │                              │ ┌─────────────────────────────┐│
│            │  │🟡 HĐ 00012460 · VPP Hòa Bình│ │ Hoạt động gần đây           ││
│            │  │   4,8 tr · OCR tin cậy thấp │ ├─────────────────────────────┤│
│            │  │   INT-01 (2 trường)          │ │ 09:42 Ngọc duyệt HĐ 12390   ││
│            │  │                              │ │ 09:31 Hà duyệt cấp 2 HĐ 12385│
│            │  │        [ Xem tất cả → ]      │ │ 09:15 Ngọc sửa đơn giá 12441 ││
│            │  └─────────────────────────────┘ └─────────────────────────────┘│
└────────────┴─────────────────────────────────────────────────────────────────┘
```

Thẻ 🔴 hiện **cả tổng tiền lệch**, không chỉ số lượng hóa đơn — đó là con số kế toán quan tâm.

### S3 — Upload và tiến độ lô

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Tải hóa đơn lên                                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌───────────────────────────────────────────────────────────────────┐     │
│   │                                                                   │     │
│   │                         ⬆                                         │     │
│   │            Kéo thả hóa đơn vào đây hoặc [ Chọn file ]             │     │
│   │                                                                   │     │
│   │     XML · PDF · PNG · JPG   ·   tối đa 20 file   ·   20 MB/file   │     │
│   │     Đã dùng hôm nay: 214/500 trang OCR · 1,82/5,00 USD            │     │
│   └───────────────────────────────────────────────────────────────────┘     │
│                                                                             │
│   Lô #a7f3 — 15 file                          Tiến độ: 11/15   ⏱ ~40 giây  │
│   ┌───────────────────────────────────────────────────────────────────┐     │
│   │ ✓ HD_00012457.xml        XML       0,8s   🔴 Lệch   → xem         │     │
│   │ ✓ HD_00012458.pdf        PDF text  2,1s   🟢 Khớp   → xem         │     │
│   │ ✓ scan_0459.jpg          OCR      11,4s   🟡 Cần xem → xem        │     │
│   │ ⟳ scan_0460.jpg          OCR — đang đọc ▓▓▓▓▓▓░░░░ 62%            │     │
│   │ ⏸ HD_00012461.pdf        Đang chờ trong hàng đợi                  │     │
│   │ ⚠ HD_00012462.pdf        Bỏ qua — trùng với HĐ 00012399 → xem     │     │
│   │ ✗ anh_mo.jpg             Lỗi — file vượt 10 trang (có 14 trang)   │     │
│   └───────────────────────────────────────────────────────────────────┘     │
│                                                                             │
│   [ Xem 15 hóa đơn của lô này ]                    [ Tải thêm file ]        │
└─────────────────────────────────────────────────────────────────────────────┘
```

Hiện **ngân sách đã dùng trong ngày** ngay trên vùng thả file — người dùng biết trước khi chạm giới hạn, không bị chặn bất ngờ.

**Đã làm khác bản phác thảo (10/10/2026):**

- Tiến độ từng file hiện theo **bước**: Tải lên → Đọc file → Đối chiếu → Xếp loại, kèm phần trăm và thời gian đã chạy.
- Trên vùng thả file hiện **chi phí đọc ước tính mỗi trang** PDF / ảnh (`GET /invoices/reading-cost`); XML không tốn gì.
- Chọn hơn 20 file thì giao diện tự chia thành nhiều lô 20 file.
- Dưới tiến độ có bảng **Lịch sử tải lên** (`GET /invoices/uploads`): mọi file đã tải, kể cả file trùng và file bị từ chối, kèm kết quả và chi phí đọc.
- Giới hạn trang mỗi file là 50, không phải 10 (PRD F16.1).
- Thả zip, thả cả thư mục và nạp JSON PO / phiếu nhập ở trang này **chưa có trên `main`**: nằm ở PR #20.

### S4 — Danh sách hóa đơn

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  Hóa đơn                                                     [ ⬆ Tải lên ]      │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 🔍 [ số HĐ, NCC, mã số thuế...        ]  Trạng thái ▼  Phân loại ▼  NCC ▼       │
│ Từ [01/09/2026] đến [20/09/2026]         Lô ▼          [ Xóa lọc ]  [ ⬇ Xuất ]  │
├─────────────────────────────────────────────────────────────────────────────────┤
│ ☐ │ │ Số HĐ     │ Nhà cung cấp     │ Ngày   │  Tổng tiền │ Lệch    │ Trạng thái │
├───┼─┼───────────┼──────────────────┼────────┼────────────┼─────────┼────────────┤
│ ☐ │🔴│ 00012457 │ Lốp xe Việt      │ 18/09  │ 48.520.000 │ 2.410.000│ Chờ duyệt 1│
│   │ │           │ ▸ PRC-01 · TAX-02│        │            │  (5,0%) │            │
├───┼─┼───────────┼──────────────────┼────────┼────────────┼─────────┼────────────┤
│ ☐ │🔴│ 00012441 │ Pin Minh Anh     │ 17/09  │ 31.200.000 │ 1.120.000│ Đã đối chiếu│
│   │ │           │ ▸ QTY-01         │        │            │  (3,6%) │            │
├───┼─┼───────────┼──────────────────┼────────┼────────────┼─────────┼────────────┤
│ ☐ │🟡│ 00012460 │ VPP Hòa Bình     │ 18/09  │  4.830.000 │       — │ Đã đối chiếu│
│   │ │           │ ▸ INT-01 (2)     │        │            │         │            │
├───┼─┼───────────┼──────────────────┼────────┼────────────┼─────────┼────────────┤
│ ☐ │🟢│ 00012458 │ Dầu nhớt Phương  │ 18/09  │ 12.400.000 │       — │ Chờ duyệt 1│
├───┼─┼───────────┼──────────────────┼────────┼────────────┼─────────┼────────────┤
│ ☐ │🟢│ 00012390 │ Đồng phục Sao Mai│ 15/09  │  8.900.000 │       — │ Đã duyệt   │
└───┴─┴───────────┴──────────────────┴────────┴────────────┴─────────┴────────────┘
│ Đã chọn 0   [ Duyệt hàng loạt ]  ← chỉ bật khi mọi HĐ đã chọn đều 🟢            │
│                                              ‹ 1 2 3 … 12 ›   62 hóa đơn        │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Duyệt hàng loạt chỉ cho phép với hóa đơn 🟢.** Chọn lẫn một hóa đơn 🟡 hay 🔴 thì nút tắt kèm giải thích — không để người dùng duyệt nhanh qua thứ cần đọc.

### S5 — Chi tiết hóa đơn · tab So sánh 3 chiều **(màn hình lõi)**

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│ ‹ Danh sách   HĐ 00012457 · Lốp xe Việt      🔴 Lệch      [Trả lại] [Từ chối]     │
│                                                            [ ✓ Duyệt cấp 1 ]      │
├───────────────────────────────────────────────────────────────────────────────────┤
│ ◉ So sánh 3 chiều │ Ngoại lệ (2) │ Tóm tắt duyệt │ Dòng thời gian                      │
├───────────────────────────────────────────────────────────────────────────────────┤
│ ┌─── Thông tin chung ───────────────────────────────────────────────────────────┐ │
│ │ Số HĐ    00012457 ⓘ      Ký hiệu  1C26TLV      Ngày   18/09/2026 ⓘ           │ │
│ │ NCC      Công ty TNHH Lốp xe Việt · MST 0101234567 ⓘ                          │ │
│ │ PO       PO-2026-0412 ⓘ (khớp qua số PO in trên HĐ)  [ đổi PO ]               │ │
│ │ Phiếu nhập  PN-2026-0871 (14/09) · PN-2026-0878 (17/09)                       │ │
│ │ Tổng tiền   48.520.000 ⚠  (tin cậy 0,82 — nên kiểm tra)                       │ │
│ └───────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
│ ┌─── Đối chiếu theo dòng ───────────────────────────┐ ┌─── Chứng từ gốc ────────┐ │
│ │                                                   │ │ [HĐ] [PO] [PN]  ⤢ ⊕ ⊖   │ │
│ │ ① Lốp Michelin 185/65R15                          │ │ ┌─────────────────────┐ │ │
│ │ ┌────────┬──────────┬──────────┬──────────┐       │ │ │ HÓA ĐƠN GTGT        │ │ │
│ │ │        │ Hóa đơn  │    PO    │ Phiếu nhập│      │ │ │ Số: 00012457        │ │ │
│ │ ├────────┼──────────┼──────────┼──────────┤       │ │ │ ...                 │ │ │
│ │ │ SL     │     8    │    10    │     8    │ ✓     │ │ │ ┌───────────────┐   │ │ │
│ │ │ Đơn giá│1.450.000⚠│ 1.380.000│        — │ ✗     │ │ │ │ 1.450.000     │◀──┼─┼─┤
│ │ │ Thành  │11.600.000│11.040.000│        — │ ✗     │ │ │ └───────────────┘   │ │ │
│ │ │ Thuế 10│ 1.160.000│ 1.104.000│        — │ ✗     │ │ │  ▲ vùng đang chọn   │ │ │
│ │ └────────┴──────────┴──────────┴──────────┘       │ │ │                     │ │ │
│ │  ⚠ Giá cao hơn PO 70.000 đ/cái (+5,07%)           │ │ │ Trang 1/1           │ │ │
│ │    → lệch 560.000 đ · vượt dung sai 2%  [PRC-01]  │ │ └─────────────────────┘ │ │
│ │    Khớp dòng: mã hàng trùng (L0)                  │ │                         │ │
│ │                                                   │ │ Nguồn trường đang chọn: │ │
│ │ ② Dịch vụ cân chỉnh thước lái                     │ │  OCR · trang 1          │ │
│ │ ┌────────┬──────────┬──────────┬──────────┐       │ │  vùng (412, 688)        │ │
│ │ │ SL     │     1    │     1    │     1    │ ✓     │ │  tin cậy 0,82           │ │
│ │ │ Đơn giá│   850.000│   850.000│        — │ ✓     │ │  [ Sửa giá trị ]        │ │
│ │ │ Thuế  8│    68.000│    68.000│        — │ ✓     │ │                         │ │
│ │ └────────┴──────────┴──────────┴──────────┘       │ │                         │ │
│ │  ✓ Khớp trong dung sai                            │ │                         │ │
│ │                                                   │ │                         │ │
│ │ ┌─── Tổng cộng ───────────────────────────────┐   │ │                         │ │
│ │ │ Tiền hàng  12.450.000 │ PO 11.890.000 │ +560.000│ │                         │ │
│ │ │ Thuế GTGT   1.228.000 │    1.172.000  │  +56.000│ │                         │ │
│ │ │ TỔNG       13.678.000 │   13.062.000  │ +616.000│ │                         │ │
│ │ │ Bằng chữ: khớp ✓                             │   │ │                         │ │
│ │ └─────────────────────────────────────────────┘   │ │                         │ │
│ └───────────────────────────────────────────────────┘ └─────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────────────┘
```

Bốn điều bắt buộc ở màn này:

- **Hàng nào lệch thì cả hàng đổi nền**, không chỉ một ô — mắt bắt nhanh hơn.
- **Ô có `confidence` thấp mang dấu `⚠`** và viền đứt nét, khác hẳn ô lệch (nền đỏ nhạt). Hai vấn đề khác nhau, không được trông giống nhau.
- **Bấm một ô thì khung chứng từ bên phải cuộn và làm nổi đúng vùng** sinh ra giá trị đó.
- **Cách khớp dòng được ghi rõ** ("mã hàng trùng (L0)", "memory NCC", "LLM đề xuất"). Kế toán cần biết ai đề xuất cặp này.

**Đã làm thêm (10/10/2026):**

- Mỗi dòng có nút **[ Gán dòng PO ]** / **[ Đổi dòng PO ]**: mở danh sách dòng của các PO đang gắn, chọn một dòng hoặc "không thuộc PO nào", ghi lý do. Hóa đơn đối chiếu lại ngay (PRD F5.9).
- Ô cần xem mang nhãn **"Cần xem"**, ô không còn câu hỏi mang nhãn **"Đạt"**; không hiện con số độ tin cậy. Ô người đã sửa ghi nguồn là "Sửa tay".
- Khung **Chứng từ gốc** bên phải có [ Phóng to ] và [ Tải về ]; bấm một ô có dấu ⚠ thì khung hiện **cách đọc** và **vị trí** của giá trị đó.
- Sửa một ô tiền thì các tổng **không tự đổi theo**; lệch giữa các ô sinh `INT-02` và chặn duyệt (PRD §4.6).

### S6 — tab Ngoại lệ và xử lý

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│ So sánh 3 chiều │ ◉ Ngoại lệ (2) │ Tóm tắt duyệt │ Dòng thời gian                      │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│ ┌─ 🔴 PRC-01 · Giá cao hơn PO ─────────────────────────── lệch 560.000 đ ───────┐ │
│ │                                                                               │ │
│ │ Dòng ① Lốp Michelin 185/65R15                                                 │ │
│ │                                                                               │ │
│ │ Đơn giá trên hóa đơn là 1.450.000 đ/cái, trong khi PO-2026-0412 ghi           │ │
│ │ 1.380.000 đ/cái. Chênh 70.000 đ/cái cho 8 cái, tương đương 560.000 đ          │ │
│ │ (+5,07%), vượt dung sai 2% đang áp dụng cho nhà cung cấp này.                 │ │
│ │                                                                               │ │
│ │ Công thức  (1.450.000 − 1.380.000) × 8 = 560.000                              │ │
│ │            560.000 / 11.040.000 = 5,07%  >  2,00%                             │ │
│ │ Nguồn      HĐ: OCR trang 1, vùng (412,688), tin cậy 0,82  [xem]               │ │
│ │            PO: PO-2026-0412 dòng 1, nhập từ Excel 02/09/2026  [xem]           │ │
│ │                                                                               │ │
│ │ ℹ Nhà cung cấp này đã 2 lần tăng giá trong 6 tháng qua. Giá trung vị           │ │
│ │   6 tháng: 1.390.000 đ/cái.                                                   │ │
│ │                                                                               │ │
│ │ Đề xuất của hệ thống:  ⭐ Yêu cầu NCC xuất hóa đơn điều chỉnh                  │ │
│ │                                                                               │ │
│ │  ( ) Chấp nhận lệch          ( ) Chờ nhập đủ hàng                              │ │
│ │  (•) Yêu cầu điều chỉnh      ( ) Từ chối hóa đơn                               │ │
│ │                                                                               │ │
│ │  Lý do (bắt buộc khi khác đề xuất)                                             │ │
│ │  ┌─────────────────────────────────────────────────────────────────────────┐  │ │
│ │  │                                                                         │  │ │
│ │  └─────────────────────────────────────────────────────────────────────────┘  │ │
│ │                                                          [ Lưu xử lý ]        │ │
│ └───────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
│ ┌─ 🔴 TAX-02 · Tiền thuế sai ────────────────────────────── lệch 56.000 đ ──────┐ │
│ │ ▸ Thuế dòng ① ghi 1.160.000, tính lại từ 11.600.000 × 10% = 1.160.000 ✓.      │ │
│ │   Nhưng tiền hàng đúng theo PO là 11.040.000 → thuế đúng 1.104.000.           │ │
│ │   Ngoại lệ này sẽ tự đóng khi PRC-01 được xử lý.          [ đã liên kết ]     │ │
│ └───────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
│ ┌─ ℹ QTY-02 · Giao hàng từng phần ────────────────────────────── không cần xử lý ┐│
│ │ Hóa đơn 8 cái trên PO 10 cái, khớp đúng số lượng đã nhận theo PN-0871 và      ││
│ │ PN-0878. Còn 2 cái chưa giao. Đây là tình huống bình thường.                  ││
│ └───────────────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────────────┘
```

Ba chi tiết quan trọng:

- **Ngoại lệ liên kết nhau** (`TAX-02` là hệ quả của `PRC-01`) được nói rõ, không bắt xử lý hai lần.
- **Ngoại lệ INFO vẫn hiển thị** nhưng thu gọn, nền xám, không có nút. `QTY-02` xuất hiện ở đây chính là bằng chứng hệ thống hiểu giao hàng từng phần — đây là chỗ đối thủ báo lệch oan.
- **Ngữ cảnh lịch sử** ("đã 2 lần tăng giá trong 6 tháng") giúp quyết định, và nó đến từ dữ liệu, không phải LLM suy đoán.

### S7 — tab Tóm tắt duyệt và xác nhận duyệt

Hệ thống **không sinh bút toán** (PRD F10). Tab này tóm tắt những gì người duyệt đang chấp nhận; kế toán tự hạch toán trong phần mềm kế toán sau khi xuất.

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│ So sánh 3 chiều │ Ngoại lệ (2) │ ◉ Tóm tắt duyệt │ Dòng thời gian                 │
├───────────────────────────────────────────────────────────────────────────────────┤
│ Hóa đơn   1C26TLV · 00012457 · 18/09/2026 · Cty TNHH Lốp xe Việt · 0101248141    │
│ Khớp với  PO-2026-0412 · Phiếu nhập PN-2026-0913                                  │
│                                                                                   │
│ ┌─────────────────────────────────────┬──────────────┬──────────────┐             │
│ │                                     │  Trên hóa đơn│  Theo PO+PN  │             │
│ ├─────────────────────────────────────┼──────────────┼──────────────┤             │
│ │ Tiền hàng                           │   12.450.000 │   11.890.000 │             │
│ │ Thuế GTGT (10%, 8%)                 │    1.228.000 │    1.172.000 │             │
│ │ Tổng thanh toán                     │   13.678.000 │   13.062.000 │             │
│ └─────────────────────────────────────┴──────────────┴──────────────┘             │
│                                                                                   │
│ Khoản lệch đang xử lý                                                             │
│  • PRC-01  Giá cao hơn PO  616.000 đ  → Yêu cầu NCC xuất hóa đơn điều chỉnh       │
│                                                                                   │
│                          [ Xuất kết quả Excel ]    [ ✓ Duyệt cấp 1 ]              │
└───────────────────────────────────────────────────────────────────────────────────┘

   Bấm Duyệt khi còn ngoại lệ được chấp nhận → hộp xác nhận:

   ┌─────────────────────────────────────────────────────────────┐
   │  Xác nhận duyệt cấp 1                                       │
   ├─────────────────────────────────────────────────────────────┤
   │  Bạn đang duyệt hóa đơn 00012457 với:                       │
   │                                                             │
   │   • 1 chênh lệch được chấp nhận:  560.000 đ                 │
   │   • Tổng thanh toán:           13.062.000 đ                 │
   │                                                             │
   │  ⚠ Hóa đơn này sẽ cần Kế toán trưởng duyệt cấp 2            │
   │    (lý do: có chênh lệch được chấp nhận)                    │
   │                                                             │
   │  Ghi chú cho người duyệt cấp 2                              │
   │  ┌───────────────────────────────────────────────────────┐  │
   │  │ Đã gọi NCC xác nhận giá mới theo phụ lục HĐ ngày 01/09│  │
   │  └───────────────────────────────────────────────────────┘  │
   │                                                             │
   │                       [ Hủy ]        [ Xác nhận duyệt ]     │
   └─────────────────────────────────────────────────────────────┘
```

Hộp xác nhận **nêu số tiền đang chấp nhận lệch**. Đây là bước cố ý làm chậm lại — duyệt lệch không được dễ như duyệt khớp.

### S8 — Hàng đợi chờ duyệt (góc nhìn KTT)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  Chờ duyệt                                        ◉ Cấp 2 (7)  │  Cấp 1 (8)     │
├─────────────────────────────────────────────────────────────────────────────────┤
│ │ │ Số HĐ     │ NCC          │  Tổng tiền │ Lý do cần cấp 2 │ Cấp 1 duyệt bởi   │
├─┼─┼───────────┼──────────────┼────────────┼─────────────────┼───────────────────┤
│ │🔴│ 00012457 │ Lốp xe Việt  │ 13.062.000 │ Chấp nhận lệch  │ Ngọc · 09:48 hôm nay│
│ │ │           │              │            │ 560.000 đ       │ "Đã gọi NCC xác..."│
├─┼─┼───────────┼──────────────┼────────────┼─────────────────┼───────────────────┤
│ │🟢│ 00012402 │ Sạc điện ABC │ 78.400.000 │ Vượt ngưỡng 50tr│ Ngọc · 08:12 hôm nay│
├─┼─┼───────────┼──────────────┼────────────┼─────────────────┼───────────────────┤
│ │🟡│ 00012399 │ Cơ khí Tân Phú│ 22.100.000│ ⚠ NCC mới       │ Ngọc · hôm qua    │
│ │ │           │              │            │ (FRD-04)        │                   │
├─┼─┼───────────┼──────────────┼────────────┼─────────────────┼───────────────────┤
│ │🟡│ 00012388 │ Dầu nhớt PL  │ 19.800.000 │ ⚠ Đổi tài khoản │ Ngọc · hôm qua    │
│ │ │           │              │            │ nhận tiền(FRD-05)│                  │
└─┴─┴───────────┴──────────────┴────────────┴─────────────────┴───────────────────┘
```

Cột **"Lý do cần cấp 2"** là cột quan trọng nhất của màn này: KTT quyết định đọc kỹ cái nào dựa vào đó. Hóa đơn do chính KTT duyệt cấp 1 không xuất hiện ở tab Cấp 2.

### S9 — Nhà cung cấp và điểm sẵn sàng tự động hóa

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  Nhà cung cấp                                  Sắp xếp: Điểm thấp nhất ▼        │
├─────────────────────────────────────────────────────────────────────────────────┤
│ Nhà cung cấp        │ MST        │ HĐ/tháng │ Tự động │ Điểm sẵn sàng           │
├─────────────────────┼────────────┼──────────┼─────────┼─────────────────────────┤
│ Cơ khí Tân Phú      │ 0312345678 │    18    │   22%   │ ▇▇▇░░░░░░░  31  Yếu     │
│ VPP Hòa Bình        │ 0309876543 │    12    │   41%   │ ▇▇▇▇▇░░░░░  48  Trung   │
│ Lốp xe Việt         │ 0101234567 │    24    │   67%   │ ▇▇▇▇▇▇▇░░░  71  Khá     │
│ Dầu nhớt Phương Linh│ 0104567890 │    31    │   88%   │ ▇▇▇▇▇▇▇▇▇░  92  Tốt     │
└─────────────────────┴────────────┴──────────┴─────────┴─────────────────────────┘
```

### S10 — Chi tiết NCC: phân rã điểm và quy tắc memory

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ ‹ Nhà cung cấp    Cơ khí Tân Phú · MST 0312345678                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│ ◉ Mức độ sẵn sàng │ Quy tắc riêng (4) │ Lịch sử hóa đơn                         │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   Điểm sẵn sàng tự động hóa        31 / 100   ▇▇▇░░░░░░░                        │
│                                                                                 │
│   Hóa đơn có XML              ▇░░░░░░░░░   6/30    →  1,8 / 30 điểm             │
│   Khớp được đơn hàng          ▇▇▇▇▇▇░░░░  19/30    → 15,8 / 25 điểm             │
│   Dòng hàng đã ánh xạ         ▇▇▇▇░░░░░░  38/94    →  8,1 / 20 điểm             │
│   Đạt 🟢 ngay lần đầu         ▇▇░░░░░░░░   6/30    →  3,0 / 15 điểm             │
│   Không có ngoại lệ lặp lại   ▇▇░░░░░░░░           →  2,3 / 10 điểm             │
│                                                                                 │
│   ┌─── Nên làm gì ────────────────────────────────────────────────────────────┐ │
│   │ 1. Đề nghị NCC gửi hóa đơn XML thay vì ảnh chụp.                          │ │
│   │    80% hóa đơn hiện là ảnh chụp → điểm dự kiến tăng lên ~59.              │ │
│   │ 2. Chuẩn hóa 56 tên hàng chưa ánh xạ được sang mã nội bộ.                 │ │
│   │    [ Xem danh sách và ánh xạ ]        → điểm dự kiến tăng lên ~71.        │ │
│   │ 3. 11 hóa đơn trong 3 tháng qua không có đơn hàng tương ứng.              │ │
│   │    Cần siết quy trình tạo PO trước khi mua.                               │ │
│   └───────────────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────────────┤
│  Tab "Quy tắc riêng":                                                           │
│  ┌──────────────┬──────────────────────────────────┬──────────┬──────────────┐  │
│  │ Loại         │ Nội dung                         │ Bằng chứng│ Trạng thái  │  │
│  ├──────────────┼──────────────────────────────────┼──────────┼──────────────┤  │
│  │ Tên hàng     │ "Bulong M8 inox" → SKU BL-M8-304 │ 5 lần    │ ✓ Đang dùng  │  │
│  │ Tên hàng     │ "Bulon M8"       → SKU BL-M8-304 │ 3 lần    │ ⏳ Chờ duyệt  │  │
│  │              │                                   │          │ [Duyệt][Bỏ] │  │
│  │ Đơn vị tính  │ 1 hộp = 100 cái                  │ 7 lần    │ ✓ Đang dùng  │  │
│  │ Dung sai giá │ 5% (mặc định 2%)                 │ KTT đặt  │ ✓ Đang dùng  │  │
│  └──────────────┴──────────────────────────────────┴──────────┴──────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

Quy tắc ở trạng thái **"Chờ duyệt"** là cốt lõi của nguyên tắc HITL áp dụng cho chính phần học máy: hệ thống đề xuất, người quyết.

### S11 — Cấu hình ngưỡng (chỉ KTT)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  Cấu hình                        Phiên bản 3 · sửa lần cuối 12/09 bởi Hà        │
├─────────────────────────────────────────────────────────────────────────────────┤
│ ◉ Dung sai │ Duyệt │ Thuế suất │ Giới hạn xử lý │ Tài khoản kế toán             │
├─────────────────────────────────────────────────────────────────────────────────┤
│  Mặc định toàn công ty                                                          │
│   Dung sai giá                [  2,0 ] %   và  [   50.000 ] đ  (phải thỏa cả hai)│
│   Dung sai số lượng           [  0,0 ] %                                        │
│   Dung sai ngày               [    3 ] ngày                                     │
│   Phiếu nhập về muộn tối đa   [   30 ] ngày                                     │
│   Ngưỡng tin cậy trường       [ 0,85 ]   ·  riêng trường tiền  [ 0,95 ]         │
│                                                                                 │
│  Ghi đè theo nhà cung cấp                                   [ + Thêm ]          │
│   ┌────────────────────┬──────────────┬──────────────┬──────────────────────┐   │
│   │ Cơ khí Tân Phú     │ giá 5,0%     │ SL 0,0%      │ [ sửa ] [ xóa ]      │   │
│   │ Sạc điện ABC       │ giá 8,0%     │ SL 2,0%      │ [ sửa ] [ xóa ]      │   │
│   └────────────────────┴──────────────┴──────────────┴──────────────────────┘   │
│                                                                                 │
│  ⚠ Thay đổi chỉ áp dụng cho hóa đơn xử lý từ thời điểm lưu.                     │
│    Hóa đơn đã đối chiếu giữ nguyên kết quả theo cấu hình lúc đó.                │
│                                                                                 │
│                       [ Xem lịch sử thay đổi ]      [ Hủy ]  [ Lưu ]            │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### S12 — Dòng thời gian / nhật ký kiểm toán của một hóa đơn

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ So sánh 3 chiều │ Ngoại lệ (2) │ Tóm tắt duyệt │ ◉ Dòng thời gian                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ●  18/09 09:02  Ngọc tải lên  HD_00012457.xml · 84 KB · sha256 3f9a…          │
│  │                                                                              │
│  ●  18/09 09:02  Hệ thống đọc xong  XML · 0,8 giây · 14 trường · tin cậy 1,00  │
│  │                                                                              │
│  ●  18/09 09:02  Hệ thống tìm chứng từ  PO-2026-0412 (qua số PO in trên HĐ)    │
│  │               PN-2026-0871, PN-2026-0878                                     │
│  │                                                                              │
│  ●  18/09 09:02  Hệ thống đối chiếu  2 dòng · khớp L0 (mã hàng) · 0 gọi LLM    │
│  │               Phát hiện: PRC-01, TAX-02, QTY-02(info)                        │
│  │                                                                              │
│  ●  18/09 09:15  Ngọc sửa trường  đơn giá dòng 1                                │
│  │               1.540.000 → 1.450.000                                          │
│  │               Lý do: OCR đọc nhầm 4 thành 5                                  │
│  │                                                                              │
│  ●  18/09 09:15  Hệ thống tính lại  phân loại 🔴 (giữ nguyên)                   │
│  │                                                                              │
│  ●  18/09 09:46  Ngọc xử lý ngoại lệ  PRC-01 → Yêu cầu NCC điều chỉnh           │
│  │               Ghi chú: "Đã gọi NCC xác nhận giá mới theo phụ lục 01/09"      │
│  │                                                                              │
│  ●  18/09 09:48  Ngọc duyệt cấp 1  chấp nhận lệch 560.000 đ                     │
│  │                                                                              │
│  ○  Đang chờ  Kế toán trưởng duyệt cấp 2                                        │
│                                                                                 │
│                                                   [ ⬇ Xuất nhật ký (Excel) ]   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

Đây là màn hình để trả lời kiểm toán, và cũng là màn hình thuyết phục nhất khi demo: nó cho thấy hệ thống **không phải hộp đen**.

### S13 — Bố cục trên điện thoại

Trên màn hình hẹp, bảng ba cột không dùng được. Chuyển sang thẻ xếp dọc theo từng dòng hàng.

```
┌───────────────────────────┐
│ ☰  HĐ 00012457       🔴   │
├───────────────────────────┤
│ Lốp xe Việt               │
│ 18/09/2026 · 48.520.000 đ │
│ Lệch 2.410.000 đ (5,0%)   │
├───────────────────────────┤
│ [So sánh][Lệch 2][BT][LS] │
├───────────────────────────┤
│ ① Lốp Michelin 185/65R15  │
│ ┌───────────────────────┐ │
│ │ Số lượng              │ │
│ │  HĐ 8  PO 10  PN 8  ✓ │ │
│ ├───────────────────────┤ │
│ │ Đơn giá            ✗  │ │
│ │  HĐ  1.450.000 ⚠      │ │
│ │  PO  1.380.000        │ │
│ │  →  +70.000 (+5,07%)  │ │
│ └───────────────────────┘ │
│ ⚠ PRC-01 · lệch 560.000đ  │
│   [ Xem và xử lý ]        │
├───────────────────────────┤
│ ② Dịch vụ cân chỉnh    ✓  │
│   Khớp trong dung sai     │
├───────────────────────────┤
│ [Trả lại] [ ✓ Duyệt ]     │
└───────────────────────────┘
```

Trên điện thoại **ưu tiên xem và duyệt**, không ưu tiên sửa trường — sửa số tiền trên màn hình nhỏ dễ sai.

---

## 5b. Màn hình thêm sau bản 1.0 *(theo `main`, 10/10/2026)*

### S14 — Lô tải lên và đồng bộ ERP

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Lô tải lên                                                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│  Đồng bộ ERP · http-feed · 4 giờ một lần          [ Đồng bộ ngay ]  (KTT)   │
│  Lần gần nhất 09:00 · Thành công · 12 sự kiện: 3 PO, 3 phiếu nhập, 6 hóa đơn│
│  ▸ Các lần đồng bộ gần đây   Bắt đầu │ Kết quả │ Sự kiện                    │
│                                                                             │
│  Lô        Nguồn       Lúc     File  Xong  Lỗi  Trạng thái                  │
│  #01a1…    Người dùng  10:42    20    20    0   ✓ Thành công         →      │
│  #01a0…    ERP         09:00     6     5    1   ⚠ Lỗi  [ Chạy lại lỗi ]  →  │
│  #019f…    Người dùng  08:15     3     3    0   ✓ Thành công         →      │
│                                                       [ Tải thêm ]          │
└─────────────────────────────────────────────────────────────────────────────┘
```

- Một lô là một lần tải lên, hoặc một lần ERP kéo về (PRD F16.6). Bấm một lô → `/batches/:id`: danh sách hóa đơn của lô.
- **[ Chạy lại lỗi ]** đưa mọi hóa đơn `FAILED` của lô vào pipeline lại. Không có hóa đơn lỗi thì báo "Không có hóa đơn lỗi nào để chạy lại".
- Chưa khai báo nguồn ERP thì khối trên ghi "chỉ kéo khi bấm" hoặc "Chưa đồng bộ lần nào", không báo lỗi.

### S15 — tab Xem bản đọc (chỗ dừng đọc)

Hiện khi đồ thị dừng ở chỗ đọc (`READING_REVIEW`, hoặc hóa đơn chỉ đọc từ ảnh — PRD F2.14). Đầu trang chi tiết có dải báo "Hóa đơn đang chờ người xem bản đọc · [ Xem bản đọc ]".

```
┌────────────────────────────────────────────────────┬──────────────────────────┐
│ Xem bản đọc (3)                                    │ Chứng từ gốc   [Phóng to]│
├────────────────────────────────────────────────────┤ ┌──────────────────────┐ │
│ Trường        Máy đọc     Vì sao phải xem     Đúng │ │                      │ │
│                                              như in│ │  (ảnh trang 1,       │ │
│ Ngày HĐ       12/08/2026  hai lần đọc khác     ☐   │ │   làm nổi vùng       │ │
│                           nhau: 12/08 · 12/09      │ │   của trường đang    │ │
│               Hoặc sửa thành [ 12/09/2026 ]        │ │   chọn)              │ │
│ Tiền thuế     1.228.000   dưới ngưỡng          ☑   │ │                      │ │
│ Dòng 3 · SL   1,250       hai lần đọc khác     ☐   │ │                      │ │
│               Hoặc sửa thành [ 1250 ]              │ └──────────────────────┘ │
│               Nhập số, ví dụ 1.450.000 hoặc 8,5.   │                          │
│                                                    │                          │
│                     [ Lưu và chạy tiếp ]           │                          │
└────────────────────────────────────────────────────┴──────────────────────────┘
```

- Mỗi dòng một câu hỏi: tích **"Đúng như in"** hoặc gõ giá trị đúng. Bấm tên trường → khung bên phải mở đúng trang.
- Lưu xong: "Đã lưu. Hệ thống chạy tiếp hóa đơn." Hóa đơn đi tiếp sang đối chiếu; tab biến mất khi hết câu hỏi.

### S16 — tab Nhập tay

Hiện khi PDF / ảnh không trích xuất được (không có khóa mô hình, trang trắng, file lạ). Form gồm các trường đầu hóa đơn (số, ký hiệu, ngày, MST người bán — "Dùng để gán nhà cung cấp trong danh mục", tổng tiền…) và bảng dòng hàng có **[ Thêm dòng ]**. Nút **[ Lưu và đối chiếu ]**. Nhập xong mà trùng hóa đơn đã có thì báo "Đã lưu, nhưng hóa đơn này trùng một hóa đơn đã có."

### S17 — tab Chế độ thuế / Cơ sở giá *(chỉ khi `DOCUMENT_INTAKE` bật, hiện chỉ ở dev)*

Đồ thị dừng hỏi khi chưa rõ hóa đơn thuộc chế độ thuế nào (GTGT trong nước, nước ngoài…) hoặc đơn giá in là giá trước hay sau thuế. Màn hiện **tín hiệu máy dùng để kết luận** và **vì sao từng cơ sở giá không khớp** (bảng đơn giá in · đơn giá chưa thuế), người chọn một phương án. Chọn "nằm ngoài phạm vi" thì hóa đơn dừng xử lý.

### S18 — Đơn hàng & phiếu nhập

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Đơn hàng & phiếu nhập                   [ Import PO ] [ Import phiếu nhập ]│
├─────────────────────────────────────────────────────────────────────────────┤
│  [ Tìm số PO…        ]   Trạng thái ▼ Mọi trạng thái                        │
│                                                                             │
│  Số PO          Nhà cung cấp            Ngày        Giá trị      Trạng thái │
│  PO-EV0000001   Cty TNHH Vật tư Nam Việt 28/08/2026 28.050.000   Đang mở  → │
│  PO-EV0000002   Cty TNHH Lốp Việt       30/07/2026     185.000   Đang mở  → │
└─────────────────────────────────────────────────────────────────────────────┘
```

- Import nhận `.xlsx`, `.xls`, `.csv` (cả file "Nhập kho" của MISA AMIS). Xong hiện "Import đơn hàng: tạo mới n, cập nhật m" và danh sách dòng lỗi nếu có.
- `/documents/:id`: dòng hàng của PO (Đặt · Đã nhận · Đã có hóa đơn · Đơn giá · Thành tiền) và các phiếu nhập kho (Số phiếu · Ngày nhận · Kho · Hàng nhận). PO chưa có phiếu nhập thì ghi "Chưa có phiếu nhập nào cho PO này."

## 6. Thành phần dùng chung

### 6.1 Màu trạng thái

| Dùng cho | Sáng | Tối | Lưu ý |
|---|---|---|---|
| 🟢 Khớp | `#16794C` nền `#E7F5EE` | `#4ADE80` nền `#0F2A1E` | |
| 🟡 Cần kiểm tra | `#A16207` nền `#FEF6E0` | `#FACC15` nền `#2B2007` | |
| 🔴 Lệch | `#B42318` nền `#FEE7E5` | `#F87171` nền `#2C0F0D` | |
| ℹ Thông tin | `#475467` nền `#F2F4F7` | `#98A2B3` nền `#1D2939` | |
| ⚠ Tin cậy thấp | viền đứt nét `#A16207` | viền đứt nét `#FACC15` | **Không** dùng nền — phải khác với ô lệch |

Màu **không bao giờ là tín hiệu duy nhất**: mọi trạng thái đi kèm biểu tượng và chữ, cho người mù màu và cho ảnh chụp đen trắng trong tài liệu.

### 6.2 Các thành phần

| Thành phần | Mô tả | Xuất hiện ở |
|---|---|---|
| `StatusPill` | Chấm màu + nhãn ("🔴 Lệch") | S2, S4, S5, S8 |
| `ConfidenceBadge` | `⚠ 0,82` — hiện khi dưới ngưỡng, ẩn khi trên | S5, S6 |
| `ExceptionChip` | `PRC-01` mã đơn sắc, rê chuột hiện tên đầy đủ | S4, S5, S6 |
| `DeltaCell` | Giá trị + chênh lệch tuyệt đối + % | S5 |
| `EvidencePopover` | Nguồn trường: loại, vị trí, tin cậy, nút "xem trong file" | S5, S6 |
| `DocumentViewer` | Khung xem PDF/ảnh, cuộn và làm nổi theo `bbox` | S5 |
| `InlineEditField` | Sửa tại chỗ, Enter lưu, Esc hủy, hiện giá trị cũ | S5 |
| `ActionRadioGroup` | Bốn hành động chuẩn, đánh dấu ⭐ cho đề xuất | S6 |
| `ApprovalConfirmDialog` | Nêu số tiền chấp nhận lệch trước khi duyệt | S7 |
| `ScoreBar` | Thanh điểm 0–100 kèm nhãn Yếu/Trung/Khá/Tốt | S9, S10 |
| `TimelineItem` | Một mục nhật ký: thời điểm, người, hành động, trước/sau | S12 |

### 6.3 Định dạng số và ngày

- Tiền: `13.062.000` (dấu chấm ngăn nghìn, không hiện `đ` trong bảng, có `đ` trong câu văn)
- Phần trăm: `5,07%` (dấu phẩy thập phân)
- Ngày: `18/09/2026`; trong dòng thời gian dùng `18/09 09:48`
- Số âm: màu đỏ và dấu trừ, không dùng ngoặc đơn
- Không bao giờ làm tròn số tiền khi hiển thị trong bảng đối chiếu

---

## 7. Trạng thái rỗng, đang tải và lỗi

Mỗi màn hình phải thiết kế đủ bốn trạng thái. Đây là chỗ hay bị bỏ quên và là chỗ người chấm hay bấm vào.

| Màn hình | Rỗng | Đang tải | Lỗi |
|---|---|---|---|
| Dashboard | "Chưa có hóa đơn nào. [Tải lên hóa đơn đầu tiên]" | Khung xương các thẻ | "Không tải được số liệu. [Thử lại]" |
| Danh sách | "Không có hóa đơn khớp bộ lọc. [Xóa lọc]" | Khung xương 5 dòng | Thanh lỗi giữ nguyên bộ lọc |
| Chi tiết | — | Khung xương từng vùng, không phải spinner toàn trang | "Không tải được hóa đơn" + nút quay lại |
| Chờ duyệt | "Không có gì chờ bạn duyệt. 🎉" | Khung xương | |
| NCC | "Chưa có nhà cung cấp. Import PO để tự tạo." | | |

**Quy tắc chung khi tính lại sau sửa trường:** chỉ làm mờ vùng bị ảnh hưởng, giữ nguyên vị trí cuộn, và làm nổi vùng vừa thay đổi trong 2 giây sau khi có kết quả.

---

## 8. Phím tắt

Kế toán xử lý hàng trăm hóa đơn — phím tắt tiết kiệm thật, không phải trang trí.

| Phím | Hành động | Ở đâu |
|---|---|---|
| `j` / `k` | Hóa đơn sau / trước | Danh sách |
| `Enter` | Mở hóa đơn đang chọn | Danh sách |
| `1` `2` `3` `4` | Chuyển tab | Chi tiết |
| `e` | Sửa trường đang chọn | Chi tiết |
| `a` | Mở hộp xác nhận duyệt | Chi tiết |
| `r` | Trả lại | Chi tiết |
| `Esc` | Đóng hộp thoại / hủy sửa | Mọi nơi |
| `/` | Nhảy vào ô tìm kiếm | Mọi nơi |
| `?` | Hiện bảng phím tắt | Mọi nơi |

Phím `a` **không** duyệt ngay — nó mở hộp xác nhận. Không có phím tắt nào gây ra hành động không hoàn tác được.

---

## 9. Bản đồ màn hình ↔ API

| Màn hình | Endpoint |
|---|---|
| S1 Đăng nhập | `POST /auth/login`, `GET /auth/me` |
| S2 Dashboard | `GET /dashboard/summary`, `GET /invoices?…`, `GET /admin/audit-logs?limit=10` |
| S3 Upload | `POST /invoices/upload` (hoặc `POST /invoices/uploads` + `…/complete`), `GET /invoices/batches/{id}`, `GET /invoices/uploads`, `GET /invoices/reading-cost` |
| S4 Danh sách | `GET /invoices` |
| S5 So sánh | `GET /invoices/{id}`, `GET /invoices/{id}/comparison`, `GET /invoices/{id}/file`, `PATCH /invoices/{id}/fields`, `POST /invoices/{id}/relink-po`, `PUT /invoices/{id}/lines/{line_id}/match`, `GET /invoices/{id}/workflow` |
| S6 Ngoại lệ | `GET /invoices/{id}/discrepancies`, `POST /discrepancies/{id}/resolve` |
| S7 Tóm tắt duyệt | `GET /invoices/{id}`, `POST /invoices/{id}/approve`, `POST /exports/approved-invoices` |
| S8 Chờ duyệt | `GET /approvals/queue`, `POST /invoices/{id}/approve|reject|return` |
| S9 NCC | `GET /vendors` |
| S10 Chi tiết NCC | `GET /vendors/{id}`, `GET /vendors/{id}/readiness`, `GET /vendors/{id}/rules`, `POST /vendors/{id}/rules`, `PATCH /vendors/rules/{id}`, `PUT /vendors/{id}/bank-account` |
| S11 Cấu hình | `GET /admin/config`, `PUT /admin/config/{name}` |
| S12 Dòng thời gian | `GET /admin/audit-logs/invoice/{id}` |
| S14 Lô tải lên | `GET /invoices/batches`, `GET /invoices/batches/{id}`, `POST /invoices/batches/{id}/retry-failed`, `GET /erp/sync-runs`, `POST /erp/sync` |
| S15 Xem bản đọc | `GET /invoices/{id}/reading`, `POST /invoices/{id}/fields/confirm`, `PATCH /invoices/{id}/fields`, `POST /invoices/{id}/reading/complete` |
| S16 Nhập tay | `POST /invoices/{id}/manual-extraction` |
| S17 Chế độ thuế | `GET /invoices/{id}/tax-assessment`, `POST /invoices/{id}/tax-assessment` |
| S18 Đơn hàng & phiếu nhập | `GET /purchase-orders`, `GET /purchase-orders/{id}`, `POST /purchase-orders/import`, `POST /goods-receipts/import` |
| Hộp thoại xuất | `POST /exports/approved-invoices`, `POST /exports/reconciliation` |

---

## 10. Thứ tự dựng màn hình

| Tuần | Màn hình | Mức hoàn thiện |
|---|---|---|
| 1 | S1, S3, S4 | Chạy được, chưa cần đẹp. Danh sách chỉ cần trạng thái và phân loại |
| 2 | S5 bản đầu | Bảng ba cột có dữ liệu thật. Chưa cần khung xem chứng từ |
| 3 | S5 đầy đủ, S6, S7, S2 | **Đây là tuần quyết định ấn tượng demo.** S5 và S6 phải xong hẳn |
| 4 | S8, S9, S10, S12 | S12 dòng thời gian là màn hình bán hàng, đừng để cuối |
| 5 | S11, S13, dark mode, trạng thái rỗng/lỗi | Đánh bóng |

**Nếu thiếu thời gian, cắt theo thứ tự:** S11 cấu hình (sửa file YAML tay) → S9/S10 readiness → S13 mobile (chỉ cần không vỡ layout) → S2 dashboard (vào thẳng danh sách).

**Không bao giờ cắt:** S5 so sánh 3 chiều, S6 ngoại lệ, S7 xác nhận duyệt, S12 dòng thời gian. Bốn màn này là toàn bộ câu chuyện sản phẩm.

### Trạng thái ngày 10/10/2026 (giao diện React trên `main`)

| Màn hình | Trạng thái | Ghi chú |
|---|:-:|---|
| S1 Đăng nhập | ✅ | |
| S2 Tổng quan | ✅ | Ba thẻ 🟢🟡🔴, chờ duyệt, danh sách cần xử lý trước |
| S3 Tải lên | ✅ | Tiến độ theo bước, chi phí đọc, lịch sử tải lên. Zip / thư mục / JSON ở PR #20, chưa vào `main` |
| S4 Danh sách | ✅ | Có hộp thoại xuất |
| S5 So sánh 3 chiều | ✅ | Có gán dòng tay, khung chứng từ gốc phóng to |
| S6 Ngoại lệ | ✅ | |
| S7 Tóm tắt duyệt | ✅ | |
| S8 Chờ duyệt | ✅ | |
| S9 / S10 NCC | ✅ | |
| S11 Cấu hình | ✅ | `/config`, chỉ KTT |
| S12 Dòng thời gian | ✅ | Tab của chi tiết hóa đơn; nhật ký toàn hệ thống ở `/audit` |
| S13 Điện thoại | ◐ | Có bố cục co giãn và chế độ tối; chưa kiểm lần lượt từng màn ở 375px |
| S14 Lô tải lên + ERP | ✅ | |
| S15 Xem bản đọc | ✅ | Bật ở stage, prod |
| S16 Nhập tay | ✅ | |
| S17 Chế độ thuế | ✅ | Chỉ dev (`DOCUMENT_INTAKE`) |
| S18 Đơn hàng & phiếu nhập | ✅ | |
| Chi phí `/costs` | ✅ | Chỉ KTT |
