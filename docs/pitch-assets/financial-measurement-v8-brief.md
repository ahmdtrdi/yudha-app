# Financial measurement slide v8

Created 21 September 2026 with the built-in image-generation/editing tool, using the supplied slide as the edit target. This is a raster slide, not an editable PowerPoint file.

Source: YUDHA_Financial_Model_v8_Tickets_Ads.xlsx, Base scenario. Revenue and cash totals were independently recomputed from revenue components and cash receipts less payments to avoid stale imported formula caches. These figures match the user's recalculated funding screenshot. No spending assumptions were changed.

## Verified slide figures

- Fundraising target: Rp300,000,000 (Assumptions B101).
- Peak cumulative cash deficit: Rp205,119,459.84, in M6.
- Cash reserve: Rp80,000,000.
- Funding requirement: Rp285,119,459.84; difference to fundraising target: Rp14,880,540.16.
- First positive operating month: M6; first positive monthly cash flow: M7; cumulative cash deficit recovered: M16.
- Year 1 net revenue: Rp755,438,391.56; Year 2: Rp1,325,705,687.66. Both are annual totals, not cumulative across years.
- Acquisition cost per activated user from paid channels: Rp7,000. This is not subscriber CAC. New-user paid conversion: 10%, an assumption.
- Year 1 blended paid-customer CAC: Rp46,579.88; paid-channel first-purchase CAC: Rp54,926.05.
- Blended Pro/Max subscription contribution per paid month: Rp32,595.85. Expected paid lifetime: 4 months. Contribution LTV: Rp130,383.38; LTV/CAC: 2.7991x; contribution payback: 1.4290 months.
- Contribution/LTV exclude fixed overhead and free-user costs. Ticket sales/redemptions remain zero until a demand forecast is entered. Forecasts are before income tax.

## Chart values (Rp million per month)

| Month | Net revenue | Operating cost |
|---|---:|---:|
| M3 | 35.818 | 61.846 |
| M6 | 67.724 | 63.602 |
| M9 | 86.107 | 64.037 |
| M12 | 97.279 | 68.302 |
| M15 | 104.717 | 69.478 |
| M18 | 110.254 | 69.609 |
| M21 | 114.840 | 69.718 |
| M24 | 118.954 | 69.815 |

## Final image-edit prompt

+Use case: text-localization / precise financial slide edit.
Edit target: attached YUDHA financial measurement slide. Recreate it cleanly at high resolution, 16:9 landscape, 3200x1800 if possible. Preserve the reference's white background, sky blue header/footer, blue and yellow palette, YUDHA logo upper-right, broadly same top-three-panels / lower chart and milestones layout. Remove the purple editor selection border. Professional crisp readable typography; exact Indonesian text and financial figures below. Make enough space, no overlapping text. This is financial forecast data, use precise labels. Do not retain any old numerical labels that conflict.

Top headline, two lines:
"Model memproyeksikan laba operasional positif mulai M6 dan arus kas bulanan positif mulai M7."
"Target pendanaan Rp300 juta mencakup kebutuhan model Rp285,1 juta untuk rencana 24 bulan."

Upper left panel:
Heading "TARGET PENDANAAN"
Large blue band "Rp300.000.000"
Below "Kebutuhan model: Rp285,1 juta"
Replace old five-category pie with a truthful three-segment donut for fundraising bridge, total Rp300 million:
blue 205.11946, yellow 80, pale purple 14.88054.
Three matching legend lines:
"Defisit kas puncak  Rp205,1 jt"
"Cadangan kas  Rp80,0 jt"
"Selisih target  Rp14,9 jt"
Small caption "Proyeksi 24 bulan • bukan alokasi biaya"

Upper middle compact blue outlined panel:
Heading "ASUMSI AKUISISI"
Label "Biaya per pengguna aktif"
Large "Rp7.000"
Below "dari kanal berbayar"
Second card label "Konversi pengguna baru"
Large "10%"
Below "ke Pro + Max"
Bottom small "Asumsi model, belum tervalidasi"
Do not call Rp7,000 CAC or cite Android benchmarks.

Upper right yellow-header metrics table:
Headers "Metrik" | "Model Tahun 1"
Rows, exact:
"CAC pelanggan berbayar (blended)" | "Rp46.580"
"CAC pembelian pertama kanal berbayar" | "Rp54.926"
"Kontribusi langganan / bulan" | "Rp32.596"
"Estimasi masa berlangganan" | "4 bulan"
"LTV kontribusi langganan" | "Rp130.383"
"LTV / blended CAC" | "2,80x"
"Payback kontribusi" | "1,43 bulan"
Small note under table: "Gabungan Pro + Max; sebelum biaya tetap dan biaya pengguna gratis."

Centered yellow divider title "PROYEKSI PERKEMBANGAN"

Lower-left grouped bar chart:
Title or axis label "Rp juta / bulan"
Legend blue "Pendapatan bersih" and coral "Biaya operasional".
Y-axis from 0 to 120, ticks 0,20,40,60,80,100,120.
X-labels M3 M6 M9 M12 M15 M18 M21 M24.
Exact values in millions for bar heights:
M3 blue35.818 coral61.846;
M6 blue67.724 coral63.602;
M9 blue86.107 coral64.037;
M12 blue97.279 coral68.302;
M15 blue104.717 coral69.478;
M18 blue110.254 coral69.609;
M21 blue114.840 coral69.718;
M24 blue118.954 coral69.815.
Blue overtakes coral at M6, not M7. No need labels atop bars.

Beside chart, blue dashed milestone box with three rows and a yellow separator:
"Laba operasional positif"  "M6"
"Arus kas bulanan positif"  "M7"
"Akumulasi defisit kas tertutup"  "M16"

Lower-right two yellow circles connected with yellow dotted line:
First circle blue "TAHUN 1" then large "Rp755,4 jt" then black small "pendapatan bersih tahunan".
Second circle blue "TAHUN 2" then large "Rp1,326 miliar" then black small "pendapatan bersih tahunan".
Both figures are ANNUAL net revenue, not monthly, not cumulative across both years. Do not use Rp100jt+.

Small footnote above footer:
"Sumber: model YUDHA v8, skenario Base • Sebelum pajak • Penjualan tiket tambahan belum diproyeksikan"
Footer sky blue rounded band with white "11  FINANCIAL MEASUREMENT"

Preserve original visual identity and logo. All numbers and Indonesian spelling must be correct. Do not add other financial claims. Output only the edited slide image.
