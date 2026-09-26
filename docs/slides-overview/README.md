# Slide tổng quan dự án

Deck 12 slide để giới thiệu nhanh dự án trong khoảng 5–7 phút. Bản ngắn hơn, dễ nghe hơn deck PRD & SAD ở [`../slides/`](../slides/).

Bản chiếu được: **https://claude.ai/artifact/JxWJhXJ28k1uC5E7ifAzrc**

---

## Nội dung

Mục lục gồm bốn phần.

| # | Đầu đề | Ý chính |
|---:|---|---|
| | **Bài toán** | |
| 1 | ĐỐI SOÁT HÓA ĐƠN TỰ ĐỘNG | AI đối chiếu, kế toán duyệt cuối |
| 2 | TỔNG TIỀN CHE MẤT SAI LỆCH | Vì sao phải so từng dòng, không chỉ so tổng |
| | **Giải pháp** | |
| 3 | NĂM BƯỚC XỬ LÝ | Luồng từ tải hóa đơn đến bút toán |
| 4 | BA NGUYÊN TẮC | Luôn có người duyệt · AI không tạo ra con số · Không chắc thì phải báo |
| 5 | ĐIỂM KHÁC BIỆT | Phân biệt lệch bình thường với lệch cần chặn |
| 6 | VAI TRÒ CỦA AI | AI làm gì, không làm gì |
| | **Tầm nhìn** | |
| 7 | PHÁP LÝ | Người ký duyệt, nhật ký không sửa được, luật thuế là cấu hình |
| 8 | DỮ LIỆU | Tách dữ liệu từng công ty, không dùng để huấn luyện |
| 9 | LỘ TRÌNH SẢN PHẨM | Xe X → doanh nghiệp vừa và nhỏ → nền tảng |
| | **Nhóm và tiến độ** | |
| 10 | PHÂN CÔNG NHÓM | Bốn người, bốn vai |
| 11 | TIẾN ĐỘ HIỆN TẠI | Đã có · Đang làm · Tiếp theo |
| 12 | CÂU HỎI THƯỜNG GẶP | Slide dự phòng cho phần hỏi đáp |

Ba slide Tầm nhìn chia hai cột: **Đã có trong thiết kế** và **Lộ trình**. Khi trình bày, phần lộ trình nói bằng "sẽ", "hướng tới" — không nói như đã làm xong.

Mỗi slide có speaker notes, xem trong chế độ trình bày của trang.

---

## Cách xem và sửa

Cấu trúc giống deck ở [`../slides/`](../slides/):

- `deck.json` — thứ tự slide, bốn phần của mục lục, khai báo bộ chữ
- `slides/<id>.html` — mỗi slide một thẻ `<section>` trên khung 1920×1080

Bản trên link là bản đang chiếu; sửa ở repo không tự đồng bộ sang đó.

Quy ước thiết kế dùng chung với deck PRD & SAD: đầu đề viết hoa toàn bộ, cụm danh từ ngắn, không dùng câu hỏi; chữ trên slide ngắn gọn, dùng từ lịch sự.
