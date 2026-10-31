import base64
import io
import os
from typing import Dict, Any, List

from app.core.logging import logger
from PIL import Image, ImageDraw, ImageFont

from reportlab.lib.pagesizes import A4
from reportlab.lib.colors import HexColor
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image as RLImage, HRFlowable
)
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.graphics.shapes import Drawing, Rect

# Font setup: prioritize Unicode TrueType fonts supporting English, Sinhala, and Tamil
FONT_REGULAR = "Helvetica"
FONT_BOLD = "Helvetica-Bold"
HAS_UNICODE_FONT = False

try:
    if os.path.exists("C:/Windows/Fonts/Nirmala.ttc"):
        pdfmetrics.registerFont(TTFont("Nirmala", "C:/Windows/Fonts/Nirmala.ttc", subfontIndex=0))
        pdfmetrics.registerFont(TTFont("Nirmala-Bold", "C:/Windows/Fonts/Nirmala.ttc", subfontIndex=1))
        pdfmetrics.registerFontFamily("Nirmala", normal="Nirmala", bold="Nirmala-Bold")
        FONT_REGULAR = "Nirmala"
        FONT_BOLD = "Nirmala-Bold"
        HAS_UNICODE_FONT = True
    elif os.path.exists("C:/Windows/Fonts/arial.ttf"):
        pdfmetrics.registerFont(TTFont("Arial", "C:/Windows/Fonts/arial.ttf"))
        pdfmetrics.registerFont(TTFont("Arial-Bold", "C:/Windows/Fonts/arialbd.ttf"))
        pdfmetrics.registerFontFamily("Arial", normal="Arial", bold="Arial-Bold")
        FONT_REGULAR = "Arial"
        FONT_BOLD = "Arial-Bold"
        HAS_UNICODE_FONT = True
except Exception as e:
    logger.debug(f"TrueType font registration notice: {e}")


class NumberedCanvas(canvas.Canvas):
    """Single-page precision canvas with professional header/footer & exact page count."""
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, total_pages):
        self.saveState()
        self.setFont(FONT_REGULAR, 7.0)
        self.setFillColor(HexColor("#64748B"))

        # Footer divider line
        self.setStrokeColor(HexColor("#CBD5E1"))
        self.setLineWidth(0.6)
        self.line(28, 22, 595.27 - 28, 22)

        # Footer Left
        self.drawString(28, 13, "BananaGuard AI • Deep Learning Banana Pathology & Severity Diagnostic Platform")

        # Footer Right - Exact page count
        page_str = f"Page {self._pageNumber} of {total_pages}"
        self.drawRightString(595.27 - 28, 13, page_str)

        self.restoreState()


FALLBACK_CONDITIONS_META_TA = {
    "healthy": ("ஆரோக்கியமானது", "எந்தவித நோயோ அல்லது சேதமோ இல்லாத உயர்தர ஆரோக்கியமான வாழைப் பழம்."),
    "anthracnose": ("அந்திரக்னோஸ்", "Colletotrichum musae பூஞ்சையால் பழத்தோலில் ஏற்படும் கரும்புள்ளி மற்றும் அழுகல் நோய்."),
    "crown_rot": ("முடி அழுகல்", "வாழைச் சீப்பு வெட்டப்பட்ட பகுதியில் பூஞ்சைத் தொற்றினால் ஏற்படும் கருமை மற்றும் மென் அழுகல்."),
    "finger_rot": ("விரல் அழுகல்", "தனித்தனி வாழை விரல் பழங்களில் ஏற்படும் கருமை நிற பூஞ்சை அழுகல்."),
    "black_end_rot": ("முனை அழுகல் நோய்", "பூ அமைந்த நுனிப்பகுதியில் பூஞ்சைத் தொற்றால் உருவாகும் காய்ந்த கருப்பு அழுகல்."),
    "bacterial_soft_rot": ("பாக்டீரியா மென் அழுகல்", "Dickeya / Pectobacterium பாக்டீரியாவால் ஏற்படும் துர்நாற்றமுடைய நீர்ம மென் அழுகல்."),
    "fusarium_rot": ("பியூசாரியம் அழுகல்", "Fusarium பூஞ்சையால் பழத்தோல் மீது வெள்ளை நிற பூஞ்சை படலத்துடன் தோன்றும் அழுகல்."),
    "bruising": ("நசுங்குதல்", "கையாளுதல் மற்றும் போக்குவரத்தின் போது ஏற்படும் அழுத்தத்தால் திசுக்கள் நசுங்கி கறுத்தல்."),
    "physical_damage": ("இயந்திர சேதம்", "வெட்டுகள், கீறல்கள் அல்லது மோதல்களால் தோலில் ஏற்படும் இயந்திர சேதம்."),
    "black_spots": ("கருப்பு புள்ளிகள்", "சுற்றுச்சூழல் அல்லது சிறிய பூஞ்சைத் தொற்றுகளால் தோலின் மேல் தோன்றும் சிறு கரும்புள்ளிகள்."),
    "scarring": ("தழும்புகள்", "இளம் பருவத்தில் பூச்சிகள் அல்லது உராய்வுகளால் தோலில் உருவாகும் தழும்புகள்."),
    "skin_splitting": ("தோல் வெடிப்பு", "அதிக ஈரப்பதம் அல்லது விரைவாகப் பழுப்பதால் தோலில் ஏற்படும் நீள வெடிப்புகள்."),
    "insect_damage": ("பூச்சி சேதம்", "பூச்சிகள் சாற்றை உறிஞ்சுவதால் பழத்தின் தோலில் ஏற்படும் சேதங்கள்."),
    "deformation": ("வடிவ மாற்றம்", "மகரந்தச் சேர்க்கை அல்லது ஊட்டச்சத்துக் குறைபாட்டால் ஏற்படும் அசாதாரண பழ வடிவம்."),
    "wrinkling": ("சுருங்குதல்", "நீர் இழப்பு அல்லது வறட்சியால் பழத்தோல் வறண்டு சுருங்குதல்."),
    "sunburn": ("சூரியக் காயம்", "நேரடி சூரிய ஒளியால் பழத்தோல் பழுப்பு அல்லது கருப்பாகக் கருகிப்போதல்."),
    "sap_latex_stain": ("பால் கறைகள்", "அறுவடையின் போது வடியும் வாழைப்பால் தோலில் பட்டு உருவாகும் கருப்பு கறைகள்."),
}


def make_gauge_bar(
    score_percent: float,
    bar_width: float = 110,
    bar_height: float = 5,
    fill_color: HexColor = HexColor("#16A34A")
) -> Drawing:
    """Create a modern rounded pill-shaped progress meter."""
    d = Drawing(bar_width, bar_height)
    # Background track
    d.add(Rect(0, 0, bar_width, bar_height, rx=2.5, ry=2.5, fillColor=HexColor("#E2E8F0"), strokeColor=None))
    # Filled active segment
    active_w = max(3.0, min(bar_width, (score_percent / 100.0) * bar_width))
    d.add(Rect(0, 0, active_w, bar_height, rx=2.5, ry=2.5, fillColor=fill_color, strokeColor=None))
    return d


def generate_reportlab_pdf(
    scan_data: Dict[str, Any],
    client_name: str,
    original_img_path: str,
    gradcam_img_path: str,
) -> bytes:
    buffer = io.BytesIO()

    # Printable width: 595.27 - (28 * 2) = 539.27 pt
    # Printable height: 841.89 - (24 + 28) = 789.89 pt
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=28,
        rightMargin=28,
        topMargin=24,
        bottomMargin=28,
    )

    content_w = 539.27
    story = []

    # Curated Brand Palette
    C_PRIMARY = HexColor("#1B5E20")       # Deep Forest Green (Brand)
    C_PRIMARY_LIGHT = HexColor("#2E7D32") # Mid Green
    C_PRIMARY_TINT = HexColor("#F0FDF4")  # Soft Mint
    C_DARK = HexColor("#0F172A")          # Deep Charcoal / Slate 900
    C_TEXT = HexColor("#334155")          # Slate 700 (Body)
    C_MUTED = HexColor("#64748B")         # Slate 500 (Labels & Subtitles)
    C_BORDER = HexColor("#E2E8F0")        # Slate 200 (Clean Dividers)
    C_CARD_BG = HexColor("#F8FAFC")       # Slate 50 (Panel Background)
    C_AMBER = HexColor("#D97706")         # Warning / Defect
    C_AMBER_BG = HexColor("#FFFBEB")      # Amber Soft
    C_RED = HexColor("#DC2626")           # Disease / Severe
    C_RED_BG = HexColor("#FEF2F2")        # Red Soft
    C_GREEN = HexColor("#16A34A")         # Healthy / Mild

    # Enable HarfBuzz shaping for all styles so Sinhala & Tamil complex scripts render flawlessly
    use_shaping = HAS_UNICODE_FONT

    # Typography Styles
    brand_title_style = ParagraphStyle(
        "BrandTitle",
        fontName=FONT_BOLD,
        fontSize=15.5,
        leading=18,
        textColor=C_PRIMARY,
        shaping=use_shaping,
    )
    brand_sub_style = ParagraphStyle(
        "BrandSub",
        fontName=FONT_REGULAR,
        fontSize=7.2,
        leading=9.5,
        textColor=C_MUTED,
        shaping=use_shaping,
    )
    meta_val_right = ParagraphStyle(
        "MetaValRight",
        fontName=FONT_REGULAR,
        fontSize=7.5,
        leading=10.5,
        alignment=2,
        textColor=C_TEXT,
        shaping=use_shaping,
    )
    card_label_style = ParagraphStyle(
        "CardLabel",
        fontName=FONT_BOLD,
        fontSize=6.5,
        leading=8.5,
        textColor=C_MUTED,
        shaping=use_shaping,
    )
    card_val_style = ParagraphStyle(
        "CardVal",
        fontName=FONT_BOLD,
        fontSize=8.5,
        leading=11,
        textColor=C_DARK,
        shaping=use_shaping,
    )
    section_head_style = ParagraphStyle(
        "SectionHead",
        fontName=FONT_BOLD,
        fontSize=8.0,
        leading=10.5,
        textColor=C_DARK,
        shaping=use_shaping,
    )
    body_style = ParagraphStyle(
        "BodyDark",
        fontName=FONT_REGULAR,
        fontSize=7.0,
        leading=9.5,
        textColor=C_TEXT,
        shaping=use_shaping,
    )
    caption_style = ParagraphStyle(
        "Caption",
        fontName=FONT_REGULAR,
        fontSize=6.8,
        leading=8.8,
        alignment=1,
        textColor=C_MUTED,
        shaping=use_shaping,
    )

    # -------------------------------------------------------------
    # SECTION A: Professional Report Header
    # -------------------------------------------------------------
    header_left = [
        Paragraph("BananaGuard AI", brand_title_style),
        Spacer(1, 1),
        Paragraph("Deep Learning Banana Pathology & Severity Diagnostic Platform", brand_sub_style),
    ]

    scan_id_short = scan_data.get("scan_id", "")[:8].upper()
    created_at_raw = scan_data.get("created_at", "")[:19].replace("T", " ")
    mode_str = str(scan_data.get("mode", "REAL")).upper()
    is_demo = (mode_str == "DEMO")

    mode_badge_html = (
        f'<font color="#D97706"><b>● DEMO INFERENCE</b></font>'
        if is_demo else
        f'<font color="#16A34A"><b>● AI PRODUCTION MODEL</b></font>'
    )

    header_right = [
        Paragraph(f"<b>Scan Ref:</b> #{scan_id_short}", meta_val_right),
        Paragraph(f"<b>Date / Time:</b> {created_at_raw}", meta_val_right),
        Paragraph(f"<b>Mode:</b> {mode_badge_html}", meta_val_right),
    ]

    header_table = Table(
        [[header_left, header_right]],
        colWidths=[content_w * 0.65, content_w * 0.35],
    )
    header_table.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
        ("LINEBELOW", (0, 0), (-1, -1), 1.5, C_PRIMARY),
    ]))
    story.append(header_table)
    story.append(Spacer(1, 4))

    # -------------------------------------------------------------
    # SECTION B: Operating Mode Notice (Retained when demo mode)
    # -------------------------------------------------------------
    if is_demo:
        demo_text = Paragraph(
            '<font color="#D97706"><b>[DEMO MODE NOTICE]</b></font> '
            'Model is operating in simulated heuristic mode with deterministic seeding. '
            'Field production weights activate upon complete model training.',
            ParagraphStyle("DemoNotice", fontName=FONT_REGULAR, fontSize=6.8, leading=9.0, textColor=HexColor("#92400E"), shaping=use_shaping)
        )
        demo_table = Table([[demo_text]], colWidths=[content_w])
        demo_table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, -1), HexColor("#FEF3C7")),
            ("BOX", (0, 0), (-1, -1), 0.6, HexColor("#F59E0B")),
            ("TOPPADDING", (0, 0), (-1, -1), 3),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
            ("LEFTPADDING", (0, 0), (-1, -1), 8),
            ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ]))
        story.append(demo_table)
        story.append(Spacer(1, 4))

    # -------------------------------------------------------------
    # SECTION C: Crop & Grower Profile Panel
    # -------------------------------------------------------------
    variety_info = scan_data.get("variety") or {}
    variety_en = variety_info.get("en", "Unspecified")
    variety_si = variety_info.get("si", "")
    variety_ta = variety_info.get("ta", "")
    
    variety_display = variety_en
    lang_parts = []
    if variety_si:
        lang_parts.append(variety_si)
    if variety_ta:
        lang_parts.append(variety_ta)
    if lang_parts:
        variety_display += f" ({' / '.join(lang_parts)})"

    cond = scan_data.get("condition") or {}
    cond_type = cond.get("type", "Unknown")

    client_cell = [
        Paragraph("GROWER / CLIENT", card_label_style),
        Paragraph(client_name or "Guest Grower", card_val_style),
    ]
    variety_cell = [
        Paragraph("BANANA VARIETY", card_label_style),
        Paragraph(variety_display, card_val_style),
    ]
    category_cell = [
        Paragraph("CATEGORY", card_label_style),
        Paragraph(cond_type, card_val_style),
    ]

    profile_table = Table(
        [[client_cell, variety_cell, category_cell]],
        colWidths=[content_w * 0.32, content_w * 0.46, content_w * 0.22],
    )
    profile_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), C_CARD_BG),
        ("BOX", (0, 0), (-1, -1), 0.6, C_BORDER),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
    ]))
    story.append(profile_table)
    story.append(Spacer(1, 6))

    # -------------------------------------------------------------
    # SECTION D: Side-by-side Visualizations (Original + Grad-CAM)
    # -------------------------------------------------------------
    img_gap = 10.0
    img_w = (content_w - img_gap) / 2.0  # ~264 pt
    img_h = 120.0

    def _fit_image(path: str, max_w: float, max_h: float, fallback_msg: str):
        if not path or not os.path.exists(path):
            return Paragraph(fallback_msg, caption_style)
        try:
            with Image.open(path) as im:
                iw, ih = im.size
                if iw <= 0 or ih <= 0:
                    return Paragraph(fallback_msg, caption_style)
                ratio = min(max_w / iw, max_h / ih)
                return RLImage(path, width=iw * ratio, height=ih * ratio)
        except Exception:
            return Paragraph(fallback_msg, caption_style)

    orig_flowable = _fit_image(original_img_path, img_w - 6, img_h - 6, "Original Photo Not Available")
    gradcam_flowable = _fit_image(gradcam_img_path, img_w - 6, img_h - 6, "Grad-CAM Overlay Not Available")

    orig_boxed = Table([[orig_flowable]], colWidths=[img_w], rowHeights=[img_h])
    orig_boxed.setStyle(TableStyle([
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("BOX", (0, 0), (-1, -1), 0.6, C_BORDER),
        ("BACKGROUND", (0, 0), (-1, -1), HexColor("#0F172A")),
        ("TOPPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
    ]))

    gradcam_boxed = Table([[gradcam_flowable]], colWidths=[img_w], rowHeights=[img_h])
    gradcam_boxed.setStyle(TableStyle([
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("BOX", (0, 0), (-1, -1), 0.6, C_BORDER),
        ("BACKGROUND", (0, 0), (-1, -1), HexColor("#0F172A")),
        ("TOPPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
    ]))

    img_col_left = [
        orig_boxed,
        Spacer(1, 2),
        Paragraph("<b>Figure A:</b> Original Specimen Capture", caption_style),
    ]
    img_col_right = [
        gradcam_boxed,
        Spacer(1, 2),
        Paragraph("<b>Figure B:</b> Saliency / Grad-CAM Attention Heatmap", caption_style),
    ]

    images_table = Table(
        [[img_col_left, img_col_right]],
        colWidths=[img_w, img_w],
    )
    images_table.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("LEFTPADDING", (0, 0), (0, 0), 0),
        ("RIGHTPADDING", (0, 0), (0, 0), img_gap / 2.0),
        ("LEFTPADDING", (1, 0), (1, 0), img_gap / 2.0),
        ("RIGHTPADDING", (1, 0), (1, 0), 0),
        ("TOPPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
    ]))
    story.append(images_table)
    story.append(Spacer(1, 6))

    # -------------------------------------------------------------
    # SECTION E: Primary Diagnostic Result Card
    # -------------------------------------------------------------
    cond_id = str(cond.get("id", "")).lower().strip()
    cond_name_en = cond.get("en", "Unknown Condition")
    cond_name_si = cond.get("si", "")
    cond_name_ta = cond.get("ta", "")
    if not cond_name_ta and cond_id in FALLBACK_CONDITIONS_META_TA:
        cond_name_ta = FALLBACK_CONDITIONS_META_TA[cond_id][0]

    cond_desc_si = cond.get("description_si", "")
    cond_desc_ta = cond.get("description_ta", "")
    if not cond_desc_ta and cond_id in FALLBACK_CONDITIONS_META_TA:
        cond_desc_ta = FALLBACK_CONDITIONS_META_TA[cond_id][1]

    cond_conf = scan_data.get("condition_confidence", 0.0) * 100.0

    sev = scan_data.get("severity") or {}
    sev_level = sev.get("en") or (sev.get("level") if sev else "None (Healthy)")
    sev_si = sev.get("si", "")
    sev_ta = sev.get("ta", "")
    sev_idx = float(scan_data.get("severity_index", 0.0))

    # Adaptive theme colors based on diagnostic condition
    if cond_type.lower() == "disease":
        res_bg = C_RED_BG
        res_box_border = HexColor("#FCA5A5")
        badge_bg = HexColor("#DC2626")
        badge_text = "#FFFFFF"
    elif cond_type.lower() == "defect":
        res_bg = C_AMBER_BG
        res_box_border = HexColor("#FCD34D")
        badge_bg = HexColor("#D97706")
        badge_text = "#FFFFFF"
    else:
        res_bg = C_PRIMARY_TINT
        res_box_border = HexColor("#86EFAC")
        badge_bg = HexColor("#16A34A")
        badge_text = "#FFFFFF"

    # Category Pill Badge + Title
    title_html = (
        f'<font size=8.5 color="{badge_bg.hexval()}"><b>[{cond_type.upper()}]</b></font> '
        f'<font size=11.5 color="{C_DARK.hexval()}"><b>{cond_name_en}</b></font>'
    )
    cond_heading = Paragraph(title_html, ParagraphStyle("FindingTitle", fontName=FONT_BOLD, fontSize=11.5, leading=14, shaping=use_shaping))

    # Multilingual Subtitle (Sinhala & Tamil) + Description
    sub_parts = []
    if cond_name_si:
        sub_parts.append(f"<b>{cond_name_si}</b>")
    if cond_name_ta:
        sub_parts.append(f"<b>{cond_name_ta}</b>")

    sub_line = " • ".join(sub_parts)
    desc_parts = []
    if cond_desc_si:
        desc_parts.append(cond_desc_si)
    if cond_desc_ta:
        desc_parts.append(cond_desc_ta)

    if desc_parts:
        sub_line += f" <font color='#64748B'>— {' • '.join(desc_parts)}</font>"

    cond_sub = Paragraph(sub_line, ParagraphStyle("FindingSub", fontName=FONT_REGULAR, fontSize=7.0, leading=9.0, textColor=HexColor("#166534"), shaping=use_shaping)) if sub_line else Spacer(1, 0)

    # 3 Structured Metric Columns
    conf_cell = [
        Paragraph("DIAGNOSTIC CONFIDENCE", card_label_style),
        Paragraph(f"<b>{cond_conf:.1f}%</b>", card_val_style),
        Spacer(1, 2),
        make_gauge_bar(cond_conf, bar_width=105, bar_height=4.5, fill_color=C_PRIMARY),
    ]

    sev_labels = []
    if sev_si:
        sev_labels.append(sev_si)
    if sev_ta:
        sev_labels.append(sev_ta)
    sev_text_full = f"<b>{sev_level}</b>" + (f" ({' / '.join(sev_labels)})" if sev_labels else "")

    sev_cell = [
        Paragraph("SEVERITY CLASSIFICATION", card_label_style),
        Paragraph(sev_text_full, card_val_style),
        Spacer(1, 2),
        Paragraph("<font size=6.5 color='#64748B'>Pathology Grade</font>", card_label_style),
    ]

    sev_gauge_color = C_GREEN if sev_idx < 35 else (C_AMBER if sev_idx < 70 else C_RED)
    idx_cell = [
        Paragraph("SEVERITY INDEX", card_label_style),
        Paragraph(f"<b>{sev_idx:.0f} / 100</b>", card_val_style),
        Spacer(1, 2),
        make_gauge_bar(sev_idx, bar_width=105, bar_height=4.5, fill_color=sev_gauge_color),
    ]

    metrics_table = Table(
        [[conf_cell, sev_cell, idx_cell]],
        colWidths=[content_w * 0.32, content_w * 0.38, content_w * 0.30],
    )
    metrics_table.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
        ("TOPPADDING", (0, 0), (-1, -1), 2),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
    ]))

    findings_content = Table(
        [
            [cond_heading],
            [cond_sub],
            [HRFlowable(width="100%", thickness=0.6, color=HexColor("#CBD5E1"), spaceBefore=2, spaceAfter=2)],
            [metrics_table],
        ],
        colWidths=[content_w - 16],
    )
    findings_content.setStyle(TableStyle([
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
        ("TOPPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
    ]))

    findings_outer = Table([[findings_content]], colWidths=[content_w])
    findings_outer.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), res_bg),
        ("BOX", (0, 0), (-1, -1), 0.75, res_box_border),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
    ]))
    story.append(findings_outer)
    story.append(Spacer(1, 4))

    # -------------------------------------------------------------
    # SECTION F: Diagnostic Probabilities / Top Predictions
    # -------------------------------------------------------------
    top_preds = scan_data.get("top_predictions", [])
    if len(top_preds) > 1:
        pred_cells = []
        for p in top_preds:
            p_id = str(p.get("id", "")).lower().strip()
            p_name = p.get("en", p.get("id", ""))
            p_conf = float(p.get("confidence", 0.0)) * 100.0
            p_si = p.get("si", "")
            p_ta = p.get("ta", "")
            if not p_ta and p_id in FALLBACK_CONDITIONS_META_TA:
                p_ta = FALLBACK_CONDITIONS_META_TA[p_id][0]
            
            p_langs = []
            if p_si:
                p_langs.append(p_si)
            if p_ta:
                p_langs.append(p_ta)

            lbl = f"<b>{p_name}</b>" + (f" ({' / '.join(p_langs)})" if p_langs else "")
            pred_cells.append(
                Paragraph(f"{lbl}: <b>{p_conf:.1f}%</b>", ParagraphStyle("PredItem", fontName=FONT_REGULAR, fontSize=6.8, leading=8.8, textColor=C_TEXT, shaping=use_shaping))
            )

        col_w_pred = content_w / float(len(pred_cells))
        diff_table = Table(
            [[pred_cell for pred_cell in pred_cells]],
            colWidths=[col_w_pred] * len(pred_cells)
        )
        diff_table.setStyle(TableStyle([
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("LEFTPADDING", (0, 0), (-1, -1), 6),
            ("RIGHTPADDING", (0, 0), (-1, -1), 6),
            ("TOPPADDING", (0, 0), (-1, -1), 3),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
            ("BACKGROUND", (0, 0), (-1, -1), HexColor("#F1F5F9")),
            ("BOX", (0, 0), (-1, -1), 0.5, C_BORDER),
        ]))
        story.append(diff_table)
        story.append(Spacer(1, 4))

    # -------------------------------------------------------------
    # SECTION G: Causes (Left) and Recommendations (Right)
    # -------------------------------------------------------------
    causes = scan_data.get("cause_factors", [])
    recs = scan_data.get("recommendations", [])

    cond_info = scan_data.get("condition")
    cond_id = cond_info.get("id") if isinstance(cond_info, dict) else scan_data.get("condition_id")
    sev_info = scan_data.get("severity")
    sev_level = sev_info.get("level") if isinstance(sev_info, dict) else scan_data.get("severity_level")
    if cond_id:
        from app.services.knowledge import knowledge_service
        fresh_causes, fresh_recs = knowledge_service.get_severity_content(str(cond_id), sev_level)
        if fresh_causes:
            causes = fresh_causes
        if fresh_recs:
            recs = fresh_recs

    col_gap = 10.0

    col_w = (content_w - col_gap) / 2.0  # ~264 pt

    # Left Column: Primary Cause Factors
    left_flowables = [
        Paragraph("<b>PRIMARY CAUSE FACTORS / හේතු සාධක</b>", section_head_style),
        HRFlowable(width="100%", thickness=0.6, color=C_BORDER, spaceBefore=2, spaceAfter=2),
    ]
    if causes:
        for idx, factor in enumerate(causes, start=1):
            en_txt = factor.get("en", "")
            si_txt = factor.get("si", "")
            ta_txt = factor.get("ta", "")
            txt = f"<b>{idx}. {en_txt}</b>"
            if si_txt:
                txt += f"<br/><font color='#475569'>&nbsp;&nbsp;&nbsp;{si_txt}</font>"
            if ta_txt:
                txt += f"<br/><font color='#64748B'>&nbsp;&nbsp;&nbsp;{ta_txt}</font>"
            left_flowables.append(Paragraph(txt, body_style))
            left_flowables.append(Spacer(1, 2))
    else:
        left_flowables.append(Paragraph("• No significant pathogen or defect factors identified.", body_style))

    # Right Column: Recommended Actions
    right_flowables = [
        Paragraph("<b>RECOMMENDED ACTIONS / නිර්දේශිත පියවර</b>", section_head_style),
        HRFlowable(width="100%", thickness=0.6, color=C_BORDER, spaceBefore=2, spaceAfter=2),
    ]
    if recs:
        for idx, r in enumerate(recs, start=1):
            en_txt = r.get("en", "")
            si_txt = r.get("si", "")
            ta_txt = r.get("ta", "")
            txt = f"<b>{idx}. {en_txt}</b>"
            if si_txt:
                txt += f"<br/><font color='#475569'>&nbsp;&nbsp;&nbsp;{si_txt}</font>"
            if ta_txt:
                txt += f"<br/><font color='#64748B'>&nbsp;&nbsp;&nbsp;{ta_txt}</font>"
            right_flowables.append(Paragraph(txt, body_style))
            right_flowables.append(Spacer(1, 2))
    else:
        right_flowables.append(Paragraph("• Regular crop inspection and standard balanced fertilization.", body_style))

    two_col_table = Table(
        [[left_flowables, right_flowables]],
        colWidths=[col_w, col_w],
    )
    two_col_table.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (0, 0), 0),
        ("RIGHTPADDING", (0, 0), (0, 0), col_gap / 2.0),
        ("LEFTPADDING", (1, 0), (1, 0), col_gap / 2.0),
        ("RIGHTPADDING", (1, 0), (1, 0), 0),
        ("TOPPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
    ]))
    story.append(two_col_table)

    # -------------------------------------------------------------
    # SECTION H: Quality Advisory (Preserved when warnings exist)
    # -------------------------------------------------------------
    q_warnings = scan_data.get("quality_warnings", [])
    if q_warnings:
        story.append(Spacer(1, 3))
        w_lines = []
        for w in q_warnings:
            w_en = w.get("en", "")
            w_si = w.get("si", "")
            w_ta = w.get("ta", "")
            w_str = f"• {w_en}"
            w_trans = []
            if w_si:
                w_trans.append(w_si)
            if w_ta:
                w_trans.append(w_ta)
            if w_trans:
                w_str += f" ({' / '.join(w_trans)})"
            w_lines.append(w_str)

        w_paragraph = Paragraph(
            f"<b>Quality Advisory:</b> " + " | ".join(w_lines),
            ParagraphStyle("WarnStyle", fontName=FONT_REGULAR, fontSize=6.8, leading=8.8, textColor=HexColor("#9A3412"), shaping=use_shaping)
        )
        w_table = Table([[w_paragraph]], colWidths=[content_w])
        w_table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, -1), HexColor("#FFF7ED")),
            ("BOX", (0, 0), (-1, -1), 0.6, HexColor("#F97316")),
            ("TOPPADDING", (0, 0), (-1, -1), 2.5),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 2.5),
            ("LEFTPADDING", (0, 0), (-1, -1), 6),
            ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ]))
        story.append(w_table)

    # -------------------------------------------------------------
    # SECTION I: Legal Disclaimer Box
    # -------------------------------------------------------------
    story.append(Spacer(1, 3))
    disclaimer_obj = scan_data.get("disclaimer") or {}
    disc_en = disclaimer_obj.get("en", "Decision-support information only. Consult an agricultural expert before applying treatments.")
    disc_si = disclaimer_obj.get("si", "තීරණ සහායක තොරතුරු පමණි. ප්‍රතිකාර යෙදීමට පෙර කෘෂිකාර්මික විශේෂඥයකුගෙන් උපදෙස් ලබා ගන්න.")
    disc_ta = disclaimer_obj.get("ta", "")

    disc_text = f"<b>Disclaimer:</b> {disc_en}"
    if disc_si:
        disc_text += f" — <font color='#64748B'>{disc_si}</font>"
    if disc_ta:
        disc_text += f" — <font color='#64748B'>{disc_ta}</font>"

    disc_table = Table(
        [[Paragraph(disc_text, ParagraphStyle("Disc", fontName=FONT_REGULAR, fontSize=6.5, leading=8.5, alignment=1, textColor=C_MUTED, shaping=use_shaping))]],
        colWidths=[content_w]
    )
    disc_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), HexColor("#F8FAFC")),
        ("BOX", (0, 0), (-1, -1), 0.5, HexColor("#CBD5E1")),
        ("TOPPADDING", (0, 0), (-1, -1), 2.5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 2.5),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ]))
    story.append(disc_table)

    # Build document strictly into 1 page using NumberedCanvas
    doc.build(story, canvasmaker=NumberedCanvas)
    return buffer.getvalue()


def _generate_pillow_pdf_fallback(
    scan_data: Dict[str, Any],
    client_name: str,
    original_img_path: str,
    gradcam_img_path: str
) -> bytes:
    """Secondary fallback PDF generator using Pillow."""
    page_w, page_h = 1240, 1754
    page = Image.new("RGB", (page_w, page_h), color=(255, 255, 255))
    draw = ImageDraw.Draw(page)

    # Header banner
    draw.rectangle([(0, 0), (page_w, 130)], fill=(27, 94, 32))
    font = ImageFont.load_default()

    draw.text((40, 25), "BananaGuard AI - Research Diagnostic Report", fill=(255, 255, 255), font=font)
    draw.text((40, 65), "Deep Learning Banana Disease, Defect & Severity Diagnostics", fill=(254, 240, 138), font=font)

    y = 150
    draw.text((40, y), f"Scan ID: {scan_data.get('scan_id', 'N/A')}", fill=(50, 50, 50), font=font)
    draw.text((600, y), f"Client: {client_name}", fill=(50, 50, 50), font=font)
    y += 30
    draw.text((40, y), f"Created At: {scan_data.get('created_at', 'N/A')}", fill=(50, 50, 50), font=font)

    # Images section
    y += 50
    img_box_size = (540, 380)
    if os.path.exists(original_img_path):
        try:
            with Image.open(original_img_path) as o_img:
                o_thumb = o_img.convert("RGB")
                o_thumb.thumbnail(img_box_size)
                page.paste(o_thumb, (40, y))
        except Exception:
            pass

    if os.path.exists(gradcam_img_path):
        try:
            with Image.open(gradcam_img_path) as g_img:
                g_thumb = g_img.convert("RGB")
                g_thumb.thumbnail(img_box_size)
                page.paste(g_thumb, (620, y))
        except Exception:
            pass

    buf = io.BytesIO()
    page.save(buf, format="PDF", resolution=150.0)
    return buf.getvalue()


def generate_scan_pdf(
    scan_data: Dict[str, Any],
    client_name: str,
    original_img_path: str,
    gradcam_img_path: str
) -> bytes:
    """Render high-resolution vector diagnostic PDF report using ReportLab with robust fallback."""
    try:
        return generate_reportlab_pdf(
            scan_data=scan_data,
            client_name=client_name,
            original_img_path=original_img_path,
            gradcam_img_path=gradcam_img_path,
        )
    except Exception as e:
        logger.warning(f"ReportLab PDF rendering error ({e}); falling back to Pillow generator.")
        return _generate_pillow_pdf_fallback(
            scan_data=scan_data,
            client_name=client_name,
            original_img_path=original_img_path,
            gradcam_img_path=gradcam_img_path,
        )
