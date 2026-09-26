# Slide trình bày PRD &amp; SAD

Deck 21 slide dùng cho buổi trình bày nhanh PRD và SAD ngày 24/09/2026. Người trình bày được gọi ngẫu nhiên, điểm của nhóm tính theo điểm người trình bày — nên mọi thành viên cần nắm được deck này.

**Không phải** pitch deck Demo Day. Pitch deck 10 slide theo cấu trúc của ban tổ chức nằm ở `P-143/presentation/`.

Bản chiếu được: **https://claude.ai/artifact/4ZjGpBUHfJzfQuhWGPMa7E**
Link riêng tư — chủ sở hữu phải chia sẻ qua menu Share thì cả nhóm mới mở được.

---

## Nội dung

Deck chia năm phần, mỗi phần mở đầu bằng một slide có nhãn "Phần N".

| # | Đầu đề | Dùng để trả lời |
|---:|---|---|
| 1 | ĐỐI SOÁT HÓA ĐƠN TỰ ĐỘNG | — |
| 2 | MỤC LỤC | Năm phần của buổi trình bày |
| | **Phần 1 — Bài toán nghiệp vụ** | |
| 3 | BA CHỨNG TỪ CẦN ĐỐI CHIẾU | Vì sao phải đối chiếu ba chiều, không phải hai |
| 4 | **RỦI RO KHI CHỈ SO TỔNG TIỀN** | Vì sao cần phần mềm, kế toán tự làm không đủ |
| 5 | BA KẾT QUẢ PHÂN LOẠI | Đầu ra của hệ thống là gì |
| | **Phần 2 — Phạm vi và luồng xử lý** | |
| 6 | PHẠM VI BẢN MVP | Cái gì làm, cái gì để ngoài |
| 7 | LUỒNG XỬ LÝ DỮ LIỆU | Bảy trạng thái của một hóa đơn |
| 8 | **CÁC LỖI THƯỜNG GẶP** | Lõi sản phẩm: bảng 37 mã ngoại lệ |
| 9 | VÍ DỤ VỀ LỆCH BỊ CHẶN | Khác gì so với hệ thống khớp cứng |
| 10 | QUY TẮC DUYỆT HAI CẤP | Kiểm soát nội bộ và tách biệt trách nhiệm |
| | **Phần 3 — Kiến trúc hệ thống** | |
| 11 | KIẾN TRÚC HỆ THỐNG | Bốn mức C4 |
| 12 | BỐI CẢNH HỆ THỐNG | Phục vụ ai, nối với hệ thống nào |
| 13 | **LUỒNG DỮ LIỆU QUA HỆ THỐNG** | Dữ liệu đi qua bốn giai đoạn, các băng cắt ngang, chỗ con người quyết định |
| 14 | SÁU KHỐI TRIỂN KHAI | Công nghệ và vai trò từng khối |
| 15 | MƯỜI BỐN MODULE | Ranh giới module, vì sao modular monolith |
| 16 | LUỒNG QUA CÁC MODULE | Nối phần nghiệp vụ với phần module |
| | **Phần 4 — Vai trò của AI** | |
| 17 | GIỚI HẠN VAI TRÒ CỦA AI | AI làm gì, không làm gì, bậc thang L0–L5 |
| 18 | CÁC ĐIỂM CẮM AI | Phần chưa làm đã có hình dạng gì |
| | **Phần 5 — Trạng thái và bước tiếp theo** | |
| 19 | **TIẾN ĐỘ HIỆN TẠI** | Nhóm đang ở đâu, khác gì so với PRD |
| 20 | SÁU VẤN ĐỀ CHƯA CHỐT | Những gì còn phải quyết |
| 21 | MƯỜI HAI CON SỐ CẦN NHỚ | Xem lại trước buổi, phòng bị gọi ngẫu nhiên |

Mỗi slide có **speaker notes**: câu nên nói, câu hay bị hỏi và cách trả lời. Xem notes trong chế độ trình bày của trang.

Ba slide quan trọng nhất nếu thiếu thời gian: **4** (vì sao cần hệ thống), **8** (lõi sản phẩm), **19** (trung thực về tiến độ).

---

## Cách xem và sửa

Deck ở dạng dữ liệu, không phải file HTML mở thẳng được:

- `deck.json` — thứ tự slide, phân đoạn, khai báo hai bộ chữ
- `slides/<id>.html` — mỗi slide một file, một thẻ `<section>` trên khung 1920×1080, mọi style viết thẳng trong thuộc tính `style`

Sửa nội dung thì sửa file tương ứng trong `slides/`, đổi thứ tự thì sửa mảng `order` trong `deck.json`. Bản trên link ở trên là bản đang chiếu; sửa ở repo không tự đồng bộ sang đó.

Muốn xuất PDF hoặc PowerPoint thì dùng menu tải về trên trang.

---

## Quy ước thiết kế

Dùng chung hệ với prototype ở [`../prototype/`](../prototype/) để ba deliverable nhìn là một bộ.

- Chữ: **Be Vietnam Pro** cho giao diện, **IBM Plex Mono** cho số tiền, mã chứng từ và mã ngoại lệ. Cả hai đều đủ dấu tiếng Việt.
- Màu: nền `#F7F8FA`, mực `#14202E`, nhấn xanh thép `#2A4A7F`. Ba màu ngữ nghĩa tách riêng khỏi màu nhấn: `#16794C` khớp, `#A16207` cần kiểm tra, `#B42318` lệch.
- Đầu đề slide: **viết hoa toàn bộ**, dạng cụm danh từ ngắn, không dùng câu hỏi. Cỡ 72px.
- Trạng thái luôn viết bằng chữ kèm màu, **không dùng emoji** — chiếu máy nào cũng hiện đúng, và người mù màu vẫn đọc được.

---

## Lưu ý về slide 19

Slide *TIẾN ĐỘ HIỆN TẠI* viết theo những gì kiểm chứng được trong repo `P-143` nhánh `feat/iam` tại ngày 23/09/2026:

- Khung 14 module, `src/app`, hai migration SQL, `tests/test_architecture.py`
- `iam` là module duy nhất đã có cài đặt thật, kèm test tích hợp trên Postgres
- Các module khác mới có tầng `domain/contracts` và `dto`

`docs/C4_DESIGN.md` đánh dấu nhiều module là đã xong và ghi nguồn là nhánh `feat/module-api` — nhánh này không có trên remote. Nếu có code chưa push thì cập nhật lại slide 19 trước khi trình bày.

---

## Số mã ngoại lệ: 37, không phải 33

Bảng ở `../PRD.md` mục 4 có đủ 37 mã: DOC 6 · QTY 5 · PRC 4 · TAX 5 · ITM 4 · INT 6 · FRD 7. Con số 33 xuất hiện ở vài bản nháp trước là sai, đã sửa. Nếu thấy chỗ nào còn ghi 33 thì sửa thành 37.
