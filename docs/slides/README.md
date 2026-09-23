# Slide trình bày PRD &amp; SAD

Deck 19 slide dùng cho buổi trình bày nhanh PRD và SAD ngày 24/09/2026. Người trình bày được gọi ngẫu nhiên, điểm của nhóm tính theo điểm người trình bày — nên mọi thành viên cần nắm được deck này.

**Không phải** pitch deck Demo Day. Pitch deck 10 slide theo cấu trúc của ban tổ chức nằm ở `P-143/presentation/`.

Bản chiếu được: **https://claude.ai/artifact/4ZjGpBUHfJzfQuhWGPMa7E**
Link riêng tư — chủ sở hữu phải chia sẻ qua menu Share thì cả nhóm mới mở được.

---

## Nội dung

| # | Slide | Dùng để trả lời |
|---:|---|---|
| 1 | Bìa | — |
| 2 | Ba tờ giấy, ba câu hỏi | Vì sao phải đối chiếu ba chiều, không phải hai |
| 3 | **Tổng tiền che mất sai phạm** | Vì sao cần phần mềm, kế toán tự làm không đủ |
| 4 | Ba kết cục của một hóa đơn | Đầu ra của agent là gì |
| 5 | Phạm vi MVP | Cái gì làm, cái gì cố tình để ngoài |
| 6 | Máy trạng thái | Hóa đơn đi qua những trạng thái nào |
| 7 | **Bảng 33 mã ngoại lệ** | Lõi sản phẩm nằm ở đâu |
| 8 | QTY-02 và QTY-01 | Khác gì so với engine khớp cứng |
| 9 | Ai được duyệt cái gì | Kiểm soát nội bộ và tách biệt trách nhiệm |
| 10 | Chuyển cảnh SAD | Bốn mức C4 |
| 11 | Mức 1 — Bối cảnh | Hệ thống phục vụ ai, nối với cái gì |
| 12 | Mức 2 — Sáu khối triển khai | Công nghệ và vai trò từng khối |
| 13 | Mức 3 — 14 module | Ranh giới module, vì sao modular monolith |
| 14 | Một hóa đơn đi qua hệ thống | Nối phần nghiệp vụ với phần module |
| 15 | AI là giác quan, không phải người quyết định | AI làm gì, không làm gì, bậc thang L0–L5 |
| 16 | Chỗ cắm AI | Phần chưa làm đã có hình dạng gì |
| 17 | **Trạng thái thật** | Nhóm đang ở đâu, lệch gì so với PRD |
| 18 | Sáu câu hỏi PRD chưa trả lời | Những gì còn phải chốt |
| 19 | Mười hai con số phải thuộc | Học tối trước, phòng bị gọi ngẫu nhiên |

Mỗi slide có **speaker notes**: câu nên nói, câu hay bị hỏi và cách trả lời. Xem notes trong chế độ trình bày của trang.

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
- Trạng thái luôn viết bằng chữ kèm màu, **không dùng emoji** — chiếu máy nào cũng hiện đúng, và người mù màu vẫn đọc được.

---

## Lưu ý về slide 17

Slide *Trạng thái thật* viết theo những gì kiểm chứng được trong repo `P-143` nhánh `feat/iam` tại ngày 23/09/2026:

- Khung 14 module, `src/app`, hai migration SQL, `tests/test_architecture.py`
- `iam` là module duy nhất đã có cài đặt thật, kèm test tích hợp trên Postgres
- Các module khác mới có tầng `domain/contracts` và `dto`

`docs/C4_DESIGN.md` đánh dấu nhiều module là đã xong và ghi nguồn là nhánh `feat/module-api` — nhánh này không có trên remote. Nếu có code chưa push thì cập nhật lại slide 17 trước khi trình bày.
