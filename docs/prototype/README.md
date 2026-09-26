# Prototype giao diện — Đối soát hóa đơn

Bản mô phỏng bấm được của luồng nghiệp vụ đầy đủ: đọc hóa đơn → đối chiếu 3 chiều với đơn hàng và phiếu nhập → xử lý ngoại lệ → duyệt hai cấp → sinh bút toán.

Dùng để chốt luồng và giao diện với nhóm và với kế toán **trước khi** viết backend. Đây là bản mô phỏng, không phải ứng dụng thật — xem mục [Cái gì thật, cái gì mô phỏng](#cái-gì-thật-cái-gì-mô-phỏng).

**Đây cũng là điểm xuất phát của giao diện thật.** Trước mắt nhóm đi tiếp từ file này bằng HTML + JavaScript thuần, sau mới chuyển sang React. Các bước nối API là F1–F6 trong [`../TEAM_PLAN.md`](../TEAM_PLAN.md).

Tài liệu liên quan: [`../BRIEF_v3.md`](../BRIEF_v3.md) · [`../PRD.md`](../PRD.md) · [`../WIREFRAME.md`](../WIREFRAME.md)

---

## Chạy thế nào

Một file HTML duy nhất, **không cần cài gì, không cần build, không có dependency**. Ba cách, chọn cách nào cũng được.

### Cách 1 — mở thẳng file (nhanh nhất)

Bấm đúp vào `docs/prototype/index.html`, hoặc từ terminal:

```bash
start docs/prototype/index.html
```

Trên macOS hoặc Linux thì thay `start` bằng `open` hoặc `xdg-open`.

### Cách 2 — chạy qua web server (khi muốn xem trên điện thoại)

```bash
npx --yes serve docs/prototype -l 8000
```

Rồi mở `http://localhost:8000`. Muốn xem trên điện thoại cùng mạng LAN thì thay `localhost` bằng địa chỉ IP của máy.

Lần đầu chạy, npx tải `serve` về mất khoảng mười giây, chưa thấy gì ngay là bình thường.

> **Máy không có sẵn Python.** Lệnh `python -m http.server` sẽ báo *Python was not found* — dùng lệnh Node ở trên. Mà thật ra cách 1 là đủ, không cần server.

### Cách 3 — bản đã deploy

Đã publish sẵn tại: **https://claude.ai/artifact/EuFsefjB62sN3Asaa9us5f**

Link này riêng tư. Muốn cả nhóm mở được thì chủ sở hữu phải chia sẻ qua menu Share trên trang.

> **Cần mạng để hiển thị đúng font.** Trang tải Inter và JetBrains Mono từ Google Fonts. Mất mạng vẫn chạy được, chỉ là rơi về font hệ thống.

---

## Kịch bản demo 5 phút

Đi đúng thứ tự này là thấy trọn bài toán nghiệp vụ.

### 1. Đăng nhập
Chọn **Nguyễn Thị Ngọc — Kế toán viên**. Không cần mật khẩu.

### 2. Ca chính: hóa đơn giá cao hơn đơn hàng

Từ dashboard, mở **HĐ 00012457 · Lốp xe Việt** trong danh sách *Cần xử lý trước*.

**Tab So sánh 3 chiều**
- Bảng ba cột Hóa đơn / Đơn hàng / Phiếu nhập, ghép theo từng dòng hàng. Hàng lệch tô nền đỏ.
- Khung chứng từ bên phải tô sáng đúng ô đang lệch.
- Xem kỹ bảng **Tổng cộng**: hóa đơn 13.678.000 đ, nhưng theo đơn hàng và hàng đã nhận chỉ 13.062.000 đ.

> **Đây là điểm đắt giá nhất của demo.** Nếu kế toán chỉ so tổng tiền hóa đơn với tổng tiền đơn hàng thì thấy 11.600.000 < 13.800.000 — hóa đơn nhỏ hơn đơn hàng, trông như "chưa dùng hết hạn mức, chắc ổn" — và duyệt. Công ty mất 560.000 đ. Chỉ khi so **từng dòng theo đơn giá** mới lòi ra. Nói câu này khi demo.

**Tab Ngoại lệ**
- `PRC-01` — giá cao hơn đơn hàng, kèm công thức và nguồn dữ liệu.
- `TAX-02` — được đánh dấu là **hệ quả** của `PRC-01`, xử lý một lần đóng cả hai.
- `QTY-02` — giao hàng từng phần, hiện màu xám *không cần xử lý*. Đây là ca mà phần mềm khác hay báo lệch oan.

Chọn một hành động → **Lưu xử lý**. Chọn khác đề xuất thì bắt nhập lý do tối thiểu 10 ký tự.

**Tab Bút toán** → xem bản xem trước, kiểm tra hai vế cân → **Duyệt cấp 1**.
Hộp xác nhận nêu rõ **đang chấp nhận lệch bao nhiêu tiền** và báo trước là sẽ cần cấp 2.

### 3. Duyệt hai cấp
Đổi vai trò sang **Trần Thu Hà — Kế toán trưởng** ở thanh trên → vào **Chờ duyệt** → duyệt cấp 2 → hóa đơn chuyển *Sẵn sàng thanh toán*.

### 4. Ba thứ nên bấm thêm

| Bấm vào | Minh họa nguyên tắc |
|---|---|
| **HĐ 00012460 · VPP Hòa Bình** 🟡 — ô đơn giá có viền đứt nét (OCR tin cậy 0,71). Bấm vào, xác nhận giá trị | *Không chắc thì phải báo.* Mọi con số đều khớp nhưng vẫn không được xếp 🟢. Xác nhận xong hóa đơn **tự chuyển 🟢** |
| **HĐ 00012402 · Sạc điện ABC** — thử duyệt cấp 2 **khi đang là Ngọc** | *Tách biệt trách nhiệm.* Nút bị khóa vì chính Ngọc đã duyệt cấp 1 |
| Tab **Dòng thời gian** của hóa đơn vừa xử lý | *Mọi kết luận truy được về nguồn.* Ghi lại đúng những thao tác vừa làm, kể cả giá trị trước và sau khi sửa |

Còn có: **Nhà cung cấp** (điểm sẵn sàng tự động hóa + khuyến nghị), **Tải lên** (bấm *Chọn file* để xem lô 6 file chạy tiến độ, có cả ca trùng và ca vượt giới hạn), **Nhật ký** và **Cấu hình** (chỉ hiện với kế toán trưởng).

Nút **Đặt lại demo** trên dải cam *Demo* ở đầu trang đưa dữ liệu về trạng thái ban đầu. Nút hình mặt trăng trên thanh đầu đổi giao diện sáng/tối. Ô tìm kiếm trên thanh đầu (phím tắt `/`) lọc thẳng danh sách hóa đơn.

---

## Cái gì thật, cái gì mô phỏng

| Thành phần | Trạng thái |
|---|---|
| Luồng trạng thái hóa đơn, điều kiện chuyển trạng thái | **Thật** — đúng theo máy trạng thái ở `PRD.md` mục 5.2 |
| Điều kiện cần duyệt cấp 2, tách biệt trách nhiệm | **Thật** — tính theo `needsL2()`, ngưỡng 50.000.000 đ |
| Điều kiện bật/tắt nút duyệt theo ngoại lệ chưa xử lý | **Thật** |
| Tính lại phân loại 🟢🟡🔴 sau khi sửa trường | **Thật** — hàm `recompute()` |
| Số tiền, công thức, bút toán | **Thật** — tính đúng, nhưng trên dữ liệu dựng sẵn |
| OCR, đọc XML, gọi mô hình ngôn ngữ | **Mô phỏng** — kết quả nạp sẵn trong `seed()` |
| Upload file | **Mô phỏng** — bấm *Chọn file* chạy một lô dựng sẵn, không đọc file thật |
| Đăng nhập, phân quyền | **Mô phỏng** — đổi vai trò bằng dropdown, không có JWT |
| Import Excel, xuất Excel | **Mô phỏng** — chỉ hiện thông báo |
| Lưu dữ liệu | **Không có** — tải lại trang là mất hết, đúng ý đồ cho demo |

---

## Sửa ở đâu

Toàn bộ nằm trong `index.html`, không tách file để ai cũng mở sửa được ngay.

| Muốn đổi | Tìm đến |
|---|---|
| Màu, font, khoảng cách | Khối `:root` ở đầu file — token màu, có sẵn cả bản sáng và tối |
| Dữ liệu demo (hóa đơn, dòng hàng, ngoại lệ, bút toán) | Hàm `seed()` — mỗi hóa đơn là một object, sửa số là giao diện đổi theo |
| Ngưỡng duyệt cấp 2 | Hằng `L2_THRESHOLD` |
| Tên và mô tả 4 hành động xử lý | Object `ACTIONS` |
| Tên trạng thái, tên phân loại | Object `STATUS`, `CLS` |
| Logic tính lại phân loại | Hàm `recompute()` |
| Điều kiện cần cấp 2 | Hàm `needsL2()` |
| Một màn hình cụ thể | Hàm `vDashboard`, `vInvoices`, `vDetail`, `vApprovals`, `vVendors`… |

Bố cục màn hình bám theo `../WIREFRAME.md`: `vDetail` ứng với S5–S7, `vApprovals` ứng với S8, `vVendors` ứng với S9–S10.

---

## Giới hạn đã biết

- Không có backend, không có lưu trữ. Mọi thay đổi mất khi tải lại trang.
- Không đọc file thật khi upload.
- Mới có 6 hóa đơn mẫu, chưa phủ hết 37 mã ngoại lệ trong `../PRD.md` mục 4 — hiện có `PRC-01`, `TAX-02`, `QTY-01`, `QTY-02`, `INT-01`.
- Chưa có màn hình quy tắc riêng từng nhà cung cấp (tab *Quy tắc riêng* ở S10 của wireframe).
- Chưa có phím tắt như mục 8 của wireframe.
- Trên điện thoại ưu tiên xem và duyệt; sửa trường trên màn hình nhỏ chưa được tối ưu.
