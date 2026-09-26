# Phân công — Invoice Reconciliation Agent

> Yêu cầu công việc cho từng thành viên · 26/09/2026 · Trạng thái: **đã chốt vai trò** — tech lead, frontend, nơi để code chốt ngày 26/09
> Dựa trên: `RESEARCH.md` (nghiên cứu kỹ thuật) · `PRD.md` (yêu cầu sản phẩm) · `BRIEF_v3.md` §12 (lộ trình 5 tuần) · `C4_DESIGN.md` (module)
> Giả định lịch: tuần 1 là 20–26/09. Nếu lịch của chương trình khác, dịch các cột tuần tương ứng.

---

## 0. Ai làm gì — một bảng

| Người | Vai trò | Sở hữu | Module trong code | Mục nghiên cứu |
|---|---|---|---|---|
| **Huy** | BA, PM, frontend | Yêu cầu, câu hỏi nghiệp vụ, kế hoạch, báo cáo tuần, deliverables, trình bày, **giao diện** | `frontend/` — đi tiếp từ `docs/prototype/` | Phụ lục A, Phần 7, mục 3.5 |
| **Dương** | ML — đọc hóa đơn | Biến mọi loại file thành dữ liệu đáng tin, và biết lúc nào nó không đáng tin | `extraction`, phần đọc của `eval/` | Phần 1, 2, 3 |
| **Hoàn** | ML — đối chiếu và an toàn AI | Khớp dòng, gán mã ngoại lệ, kiểm thuế và MST, chống tấn công | `reconciliation`, `vendor`, `semantic`, phần luật của `rules` | Phần 4, 5, mục 1.5 |
| **Giáp** | BE chính, **tech lead** | Nền tảng, luồng xử lý, ngân sách, quan sát, deploy, hợp đồng giữa các phần | `core`, `app`, `iam`, `invoice`, `procurement`, `approval`, `ledger`, `audit`, `reporting`, `erp`, khung `gateway` | Phần 6 |

Tương ứng với phân công A B C D trong `BRIEF_v3.md` và `RESEARCH.md`: **A = Dương · B = Hoàn · C = Giáp · D = Huy**.

---

## 1. Tech lead: Giáp

Đã chốt ngày 26/09.

**Vì sao Giáp:**
- Chỗ các phần ghép vào nhau — schema bàn giao, interface `gateway`, luồng xử lý — đều nằm trong phần backend. Người giữ những chỗ đó là người phải quyết khi có tranh chấp kỹ thuật.
- Hai bạn ML đang gánh hai phần rủi ro nhất của sản phẩm: đọc hóa đơn và đối chiếu. Giao thêm việc điều phối kỹ thuật cho một trong hai là lấy thời gian khỏi đúng chỗ khó nhất.

**Tech lead chịu trách nhiệm:**
- Chốt các hợp đồng bàn giao ở mục 2, ngay đầu tuần 2
- Review mọi thay đổi trước khi vào nhánh chính
- Quyết khi nào code đủ ổn để đưa lên P-143
- Giữ `C4_DESIGN.md` khớp với code thật
- Ghi quyết định lớn thành ADR ngắn: chọn mô hình đọc, LangGraph, Langfuse
- Quyết khi hai người bất đồng về kỹ thuật

**Rủi ro: Giáp gánh nặng nhất nhóm.** Cách giảm tải:
- Dương và Hoàn tự gắn trace cho phần của mình (mục G6), Giáp chỉ dựng khung
- Kết nối phần mềm kế toán (`erp`) chỉ làm interface, không làm thật trong MVP
- Nếu trễ, cắt màn hình điểm sẵn sàng nhà cung cấp trước tiên — đúng thứ tự cắt trong `BRIEF_v3.md`

---

## 2. Hợp đồng bàn giao — chốt trước, làm song song sau

Đây là phần quan trọng nhất của bản phân công. Chốt được định dạng dữ liệu đi qua ranh giới giữa hai người thì bốn người làm song song được, không ai phải chờ ai.

```
Dương  ──ExtractionResult──►  Hoàn  ──ReconciliationResult──►  Giáp  ──API──►  Huy (giao diện)
  ▲                             ▲                                │
  └──────── gateway (gọi OCR, gọi mô hình, ngân sách, cache) ────┘
```

**`ExtractionResult`** — Dương giao cho Hoàn

```
source_format:  XML | PDF_TEXT | SCAN
segments:       [ { pages: [1, 2, 3], kind: invoice | attachment } ]
header:         { tên_trường → FieldValue }
lines:          [ { line_no, fields: { tên_trường → FieldValue } } ]
totals:         { subtotal, tax_by_rate, total, amount_in_words }   — đều là FieldValue
checks:         { sum_ok, words_ok, stt_continuous, ... }
cost:           { tokens_in, tokens_out, usd }

FieldValue = {
  value,
  confidence:  0..1   — về 0 nếu trượt bất kỳ bộ kiểm nào
  source:      xml | pdf_text | ocr | manual
  evidence:    { xpath }  hoặc  { page, bbox, bbox_verified }
}
```

**`ReconciliationResult`** — Hoàn giao cho Giáp

```
po_links:        [ { po_id, linked_by, confidence } ]
line_matches:    [ { invoice_line, po_line, grn_lines, level: L0..L5,
                     matched_by, confidence, qty_delta, price_delta, amount_delta, formula } ]
discrepancies:   [ { code, severity, line?, delta_amount, formula, sources, proposed_action } ]
classification:  GREEN | YELLOW | RED
```

Câu giải thích cho kế toán **sinh riêng, từ `discrepancies`** — không bao giờ từ chữ tự do trên hóa đơn (`RESEARCH.md` mục 5.2).

**API cho giao diện** — Giáp giao cho Huy: theo `PRD.md` mục 8, phần endpoint mà giao diện cần. Trang Swagger ở `/docs` do FastAPI sinh sẵn là tài liệu API sống — có endpoint nào thì Huy nối được endpoint đó, không phải chờ viết tài liệu.

**Ca test** — ai cũng dùng: một thư mục gồm file hóa đơn, PO, phiếu nhập, và đáp án đúng gồm giá trị từng trường cộng danh sách mã ngoại lệ.

---

## 3. Yêu cầu cho từng người

Mỗi yêu cầu có tuần dự kiến và **điều kiện xong** — không đạt điều kiện thì chưa tính là xong.

### 3.1 Huy — BA, PM, frontend

**Phần BA**

| # | Việc | Tuần | Điều kiện xong |
|---|---|---|---|
| U1 | Cập nhật `PRD.md` theo 13 việc ở Phụ lục A của `RESEARCH.md` — viết yêu cầu, người làm là Dương, Hoàn, Giáp | 2 | PRD có mục đầu vào và hóa đơn dài, mã ngoại lệ mới cho MST người mua, cấu hình thuế 8% có ngày kết thúc |
| U2 | Chốt các câu hỏi mở với mentor hoặc Xe X: Q1–Q6 trong `USER_STORIES.md`, hai câu về đầu vào (một file chứa nhiều hóa đơn? bảng kê?), dung sai, ngưỡng duyệt cấp 2, thông tư 200 hay 133 | 2 | Mỗi câu có quyết định và ngày chốt, ghi vào PRD |
| U3 | Soạn kịch bản kiểm thử chấp nhận từ 18 tình huống trong `USER_STORIES.md`, tổ chức buổi dùng thử với kế toán | 4 | Biên bản buổi dùng thử, có số đo thời gian đối chiếu trước và sau — mục tiêu giảm 50% |
| U4 | Định nghĩa quy trình kiểm tra ngẫu nhiên hóa đơn đã xếp Khớp | Sau | Tỉ lệ lấy mẫu, ai kiểm, ghi kết quả ở đâu |

**Phần PM**

| # | Việc | Tuần | Điều kiện xong |
|---|---|---|---|
| P1 | Kế hoạch tuần, báo cáo tuần cho mentor (`JOURNAL.md`), nhật ký công việc (`WORKLOG.md`) | Hằng tuần | Nộp đúng hạn, ở P-143 |
| P2 | Theo dõi checklist 10 deliverables của Demo Day | Từ tuần 2 | Mỗi deliverable có người chịu trách nhiệm và hạn |
| P3 | Việc với mentor và ban tổ chức: xin dữ liệu mẫu, xác nhận Langfuse đáp ứng deliverable *AI Logs*, xin credit Google Cloud nếu dùng Document AI | 2 | Có câu trả lời bằng văn bản |
| P4 | Theo dõi bảng rủi ro trong `BRIEF_v3.md` §13; quyết thứ tự cắt khi trễ | Hằng tuần | Rủi ro cập nhật trong báo cáo tuần |
| P5 | Pitch deck 10 slide theo cấu trúc ban tổ chức và video demo tối đa 5 phút | 5 | Nằm trong `presentation/` của P-143 |

**Lưu ý cho P1 và P5.** Theo `docs/guide/chapter-02.md` của chương trình, chỉ repo của đội trong org của khóa được tính là bài nộp. Báo cáo tuần, pitch deck, video và mọi deliverable phải nằm ở P-143.

**Phần frontend** — đi tiếp từ prototype ở `docs/prototype/`, thay dữ liệu mẫu bằng lời gọi API

| # | Việc | Tuần | Điều kiện xong |
|---|---|---|---|
| F1 | Đăng nhập thật bằng JWT, tự làm mới token khi hết hạn | 3 | Hai vai trò đăng nhập được; token hết hạn thì tự làm mới, không đẩy người dùng ra ngoài |
| F2 | Thay dữ liệu mẫu bằng lời gọi API theo `PRD.md` §8: danh sách, so sánh ba chiều, xử lý ngoại lệ, duyệt, trả lại, từ chối, hàng đợi duyệt, nhà cung cấp | 3 | Đi hết kịch bản demo trên dữ liệu lấy từ API; bản chạy thật không còn dữ liệu mẫu |
| F3 | Tải lên nhiều file và theo dõi tiến độ lô | 3 | Thấy từng file đổi trạng thái; file trùng và file vượt giới hạn hiện đúng thông báo |
| F4 | Thông báo theo mã lỗi `401`, `403`, `404`, `409`, `413`, `429`; trạng thái đang tải và trạng thái rỗng | 4 | Mỗi mã lỗi có câu thông báo nói rõ chuyện gì xảy ra và làm gì tiếp |
| F5 | Hóa đơn dài: mặc định chỉ hiện dòng lệch; chỉ tô vùng bằng chứng khi `bbox_verified` | 4 | Hóa đơn 200 dòng vẫn mở nhanh; vùng chưa xác minh không được tô — `RESEARCH.md` mục 3.5 |
| F6 | Deploy giao diện, cấu hình CORS với API | 4 | Có live URL cho giao diện |
| F7 | Chuyển giao diện sang React, dùng lại module gọi API và bộ màu | Sau | Chạy đủ kịch bản demo như bản HTML |

Vì sau này chuyển sang React, viết phần nối API sao cho mang sang được nguyên vẹn: tách **lời gọi API** và **xử lý dữ liệu** thành ES module riêng — `<script type="module">`, vẫn không cần build — và **không đụng tới giao diện** trong các module đó. Khi chuyển React chỉ phải viết lại phần hiển thị; phần gọi API, làm mới token, định dạng số tiền dùng lại được. Bộ màu trong khối `:root` cũng mang sang được.

**Chỉ số Huy chịu trách nhiệm:** 10/10 deliverables · báo cáo tuần đúng hạn · thời gian đối chiếu của kế toán giảm ít nhất 50% · giao diện chạy hết kịch bản demo trên API thật.

**Tải của Huy tăng vì nhận thêm frontend.** Để bù: U4 đã chuyển sang sau MVP; ở tuần 5 cả nhóm cùng quay video, Huy dựng và ghép.

### 3.2 Dương — ML, đọc hóa đơn

**Mục tiêu:** mọi file — XML, PDF, ảnh, file chứa nhiều hóa đơn — thành `ExtractionResult` đáng tin, và **biết chính xác trường nào không đáng tin**.

| # | Việc | Tuần | Điều kiện xong |
|---|---|---|---|
| D1 | So sánh hai đường đọc: Gemini 3.1 Flash-Lite ở mức MEDIUM và Document AI, trên cùng 30 hóa đơn scan | 2 | Bảng so sánh độ chính xác trường, **tỉ lệ sai mà không gắn cờ**, chi phí mỗi trang, thời gian — và một quyết định, ghi vào ADR |
| D2 | Bộ đọc PDF có chữ và bộ đọc ảnh, cài sau interface `InvoiceExtractor` | 2 | PDF và ảnh không còn rơi vào `FAILED` với mã `UNSUPPORTED_FORMAT`; có unit test |
| D3 | Chuẩn hóa kiểu dữ liệu: giải quyết dấu chấm, dấu phẩy bằng số học; đọc ngày viết bằng chữ; sửa nhầm lẫn OCR trong mã số thuế | 2 | Test phủ các ca mơ hồ như `1.234` và `1,500`, ngày dạng *"Ngày 18 tháng 09 năm 2026"* |
| D4 | Tách hóa đơn trong file nhiều trang — phân loại trang thành trang đầu, giữa, cuối, bảng kê | 3 | Đo độ chính xác tách trên bộ file ghép; đoạn tách không chắc thì chuyển người |
| D5 | Bảng qua nhiều trang: mang tiêu đề theo, chia lô theo dòng, kiểm STT liền mạch, nhận vai trò cột bằng SL × đơn giá = thành tiền | 3 | Hóa đơn 20 trang, 200 dòng đọc đủ dòng, STT không đứt |
| D6 | Độ tin cậy từng trường và hiệu chỉnh ngưỡng trên bộ đánh giá | 3–4 | Ngưỡng do dữ liệu chọn; **sai mà không gắn cờ ≈ 0** trên bộ đánh giá |
| D7 | Xác minh bounding box: cắt vùng, đọc lại bằng Tesseract tiếng Việt, so với giá trị | 4 | Báo được tỉ lệ bbox xác minh được; bbox chưa xác minh thì giao diện không tô |
| D8 | Dữ liệu hình ảnh cho đánh giá: render XML (lấy từ bộ sinh của Hoàn) thành PDF và ảnh scan có nhiễu — nghiêng, mờ, bóng, mộc đè lên số; cộng dữ liệu cào; cộng file ghép nhiều hóa đơn cho D4 | 2–3 | Ít nhất 100 ảnh có đáp án đúng |
| D9 | Chạy thử mô hình mở — DeepSeek-OCR 2, Qwen3-VL, PaddleOCR-VL — trên cùng bộ đánh giá, nếu có máy GPU | Sau | Bảng so với đường API |

**Chỉ số Dương chịu trách nhiệm:** độ chính xác trường XML 100% · trường tiền của PDF và scan ≥ 99% trên các trường không gắn cờ · **sai mà không gắn cờ ≈ 0** · độ chính xác tách hóa đơn · chi phí mỗi trang · p95 thời gian đọc.

**Cần từ người khác:** Giáp — `gateway` có ngân sách, cache, thử lại · Hoàn — XML từ bộ sinh dữ liệu · Huy — quyết định được gửi dữ liệu lên dịch vụ nào.

### 3.3 Hoàn — ML, đối chiếu và an toàn AI

**Mục tiêu:** từ `ExtractionResult` cùng PO và phiếu nhập → khớp đúng dòng, gán đúng mã ngoại lệ, giải thích được, và **không bị lừa**.

| # | Việc | Tuần | Điều kiện xong |
|---|---|---|---|
| H1 | Bộ sinh dữ liệu nghiệp vụ: XML hóa đơn hợp lệ, PO và phiếu nhập tương ứng, cài sẵn các kiểu lệch có nhãn; và sinh PO, phiếu nhập từ hóa đơn cào về | 2 | 300 bộ có đáp án mã ngoại lệ đúng, phân bổ đúng `PRD.md` §12.1 |
| H2 | Kiểm mã số thuế: chữ số kiểm tra cho dạng 10 và 13 số bằng `stdnum.vn.mst`; định dạng 12 số; **MST người mua bằng MST công ty**; MST người bán khớp danh mục nhà cung cấp | 2 | Test với MST công khai thật, cộng các ca sai một chữ số và đảo hai chữ số liền nhau |
| H3 | Khớp dòng L0 đến L3: mã hàng, bộ nhớ nhà cung cấp, chuỗi chuẩn hóa — bỏ dấu, chuẩn hóa Unicode, bỏ ký tự vô hình — và so chuỗi gần đúng | 2–3 | Đo recall khớp dòng trên bộ đánh giá |
| H4 | Khớp dòng L4: `LlmArbiter` thay cho `InconclusiveArbiter`, **chỉ được chọn trong danh sách ứng viên** | 3 | Đếm được số lần gọi mô hình mỗi hóa đơn |
| H5 | Kiểm thuế: sửa `vat_rates.yaml` — 8% **hết hiệu lực 31/12/2026** và chỉ cho nhóm hàng đủ điều kiện; tính thuế từng dòng rồi mới cộng; các mã `TAX-01` đến `TAX-05` | 3 | Test ví dụ ở `PRD.md` §6, và các ca sát mốc 30/6/2025 – 01/7/2025, 31/12/2026 – 01/01/2027 |
| H6 | Phân loại, đề xuất xử lý, viết giải thích — giải thích **chỉ từ dữ kiện có cấu trúc** | 3 | Mọi ngoại lệ có công thức và nguồn; test: chữ tự do chứa lệnh trên hóa đơn không lọt vào câu giải thích |
| H7 | Phát hiện bất thường `FRD-01` đến `FRD-07`, cộng so lớp chữ PDF với ảnh render ở trường tiền — phối hợp với Dương | 4 | Recall các ca gian lận đã cài ≥ 95% |
| H8 | Bộ nhớ nhà cung cấp: học alias từ lần sửa của kế toán viên, chỉ có hiệu lực khi kế toán trưởng duyệt | 4 | Hóa đơn thứ tư của cùng nhà cung cấp khớp ở bậc L1 và **không gọi mô hình** — kiểm được trong bảng ghi lời gọi |
| H9 | Thử mô hình gác Llama Prompt Guard 2 trên câu tấn công tiếng Việt tự soạn | Sau | Báo cáo ngắn tỉ lệ bỏ sót, kết luận dùng hay không |

**Chỉ số Hoàn chịu trách nhiệm:** recall chỗ lệch ≥ 98% · precision ≥ 85% · độ chính xác mã ngoại lệ ≥ 85% · **tỉ lệ báo oan `QTY-02` ≤ 5%** · recall gian lận ≥ 95% · số lần gọi mô hình mỗi hóa đơn.

**Cần từ người khác:** Dương — `ExtractionResult` · Giáp — dữ liệu PO và phiếu nhập qua `procurement`, danh mục nhà cung cấp, `gateway` · Huy — dung sai, ngưỡng, các câu hỏi mở đã chốt.

### 3.4 Giáp — BE chính, tech lead

**Mục tiêu:** nền tảng chạy thật, an toàn, đo được chi phí — và mọi người cắm phần việc của mình vào mà không giẫm lên nhau.

| # | Việc | Tuần | Điều kiện xong |
|---|---|---|---|
| G1 | **[Tech lead]** Chốt hợp đồng bàn giao ở mục 2 thành schema Pydantic trong code | Đầu tuần 2 | Có trong code và tài liệu, ba người còn lại đồng ý |
| G2 | Gộp `feat/base_module` và `feat/iam` về nhánh chính | 2 | Nhánh chính chạy được, CI xanh |
| G3 | Nối các module vào API theo `PRD.md` §8: tải lên, nhập PO và phiếu nhập từ Excel, đối chiếu, duyệt hai cấp với tách biệt trách nhiệm, bút toán và xuất file, nhật ký, báo cáo | 2–3 | Đi hết luồng bằng API với dữ liệu mẫu; test tích hợp cho tách biệt trách nhiệm (trả `409`) và cách ly tenant (trả `404`) |
| G4 | Thay `InProcessPipeline` bằng LangGraph có Postgres checkpointer; bước chờ duyệt là điểm dừng thật | 3 | Test: khởi động lại khi hóa đơn đang chờ duyệt cấp 1, lên lại vẫn duyệt tiếp được |
| G5 | `gateway`: ngân sách theo từng tenant theo ngày và tháng, trần mỗi hóa đơn, ngắt mạch; cache theo khóa gồm mã băm, bước, phiên bản prompt, mô hình; thử lại có giãn cách; mô hình dự phòng; mã lỗi hệ thống để chuyển người | 3 | Test: vượt ngân sách thì dừng và chuyển người; thử lại không bị tính tiền hai lần |
| G6 | Quan sát: OpenTelemetry gửi về Langfuse tự host; một trace mỗi hóa đơn, một span mỗi bước; `trace_id` lưu trong bảng hóa đơn; che số tài khoản | 3 | Ảnh chụp trace dùng được cho deliverable *AI Logs* |
| G7 | Khung harness đánh giá: một lệnh chạy lại bộ ca test, tính chỉ số, so với lần trước; bản 20 ca chạy trong CI | 3 | Một lệnh sinh ra `eval/results/report.md`. Dương và Hoàn viết phần chấm của mình |
| G8 | Deploy API: lần đầu ở tuần 2, bản cuối ở tuần 5 | 2, 5 | Có live URL. **Kiểm nơi deploy có PostgreSQL 18** — code đang dùng `uuidv7()` có sẵn từ bản 18. Database miễn phí của Render bị xóa sau 30 ngày |

**Việc thường xuyên của tech lead:** review mọi thay đổi vào nhánh chính · quyết thời điểm đưa code lên P-143 · giữ `C4_DESIGN.md` khớp code · ghi ADR · gỡ tranh chấp kỹ thuật.

**Chỉ số Giáp chịu trách nhiệm:** test coverage ≥ 60% · p95 thời gian API · chi phí đo được theo từng tenant · cách ly tenant · live URL chạy ổn định khi demo.

**Cần từ người khác:** Dương và Hoàn — dùng `gateway` đúng cách và tự gắn trace cho phần của mình · Huy — yêu cầu nghiệp vụ đã chốt.

---

## 4. Lịch theo tuần

| Tuần | Huy | Dương | Hoàn | Giáp |
|---|---|---|---|---|
| **2** | Chốt câu hỏi mở · cập nhật PRD · xin dữ liệu, xác nhận Langfuse | So sánh hai đường đọc · bộ đọc PDF và ảnh · chuẩn hóa kiểu | Bộ sinh dữ liệu · kiểm MST · khớp L0–L3 | **Chốt hợp đồng** · gộp nhánh · nối API · deploy lần đầu |
| **3** | Đăng nhập thật · nối giao diện với API · tải lên và theo dõi lô | Tách hóa đơn · bảng nhiều trang · độ tin cậy | Khớp L4 · kiểm thuế · phân loại và giải thích | LangGraph · ngân sách `gateway` · Langfuse · khung đánh giá → **xong phần Cơ bản** |
| **4** | Buổi dùng thử với kế toán · thông báo lỗi · hóa đơn dài · deploy giao diện | Hiệu chỉnh ngưỡng · xác minh bbox · chạy đánh giá phần đọc | Bất thường · bộ nhớ nhà cung cấp · chạy đánh giá phần đối chiếu | Duyệt hai cấp hoàn chỉnh · test cách ly tenant |
| **5** | Pitch deck · dựng video · nộp đủ 10 deliverables vào P-143 | Sửa lỗi, đo lại · quay video | Sửa lỗi, đo lại · quay video · thử mô hình gác nếu còn thời gian | Deploy bản cuối · README · quay video |

Mốc chung khớp với `BRIEF_v3.md` §12: deploy lần đầu ở tuần 2, xong phần Cơ bản ở tuần 3, chạy đánh giá ở tuần 4, deck và video ở tuần 5.

---

## 5. Các quyết định

| # | Quyết định | Kết quả |
|---|---|---|
| 1 | Tech lead | **Đã chốt: Giáp** |
| 2 | Frontend | **Đã chốt: Huy.** Trước mắt đi tiếp từ prototype bằng HTML + JavaScript thuần; **sau chuyển sang React**, thời điểm chưa chốt |
| 3 | Nơi để code | **Linh hoạt.** Bản nộp và mọi deliverable nằm ở P-143 |
| 4 | Dương và Hoàn nhận phần nào | Đề xuất như mục 3 — đổi cho nhau nếu thế mạnh ngược lại |
