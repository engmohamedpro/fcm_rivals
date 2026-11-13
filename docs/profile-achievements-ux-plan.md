# خطة تحسين Profile و Achievements — مهام للمطوّر

**تاريخ:** 2026-11-11 · **أساس المراجعة:** كود `99733bb` (profile_screen / achievements_screen / streak_card / title_badge_showcase)

## خلاصة المراجعة الصريحة (فصل الحقيقة عن الرأي)

**حقيقة مقيسة (كود/أرقام):**
- 36/36 زوج ألوان في الشاشتين يعدّي WCAG 2.2 AA (حسبت الواحد في `scripts/wcag_audit.py` — الأرقام موجودة). **الألوان ليست المشكلة.**
- Achievements يعرض **42 كارت** في **10 أقسام** بسكرول واحد طويل بلا أي تجميع أو فلترة؛ كل كارت فيه 5-7 عناصر (badge + title + desc + bar + readout + chip + زر).
- Profile = 7 كتل عمودية متتابعة (identity / stats / silverware / history / cabinet / gallery) — كله بنفس وزن البصر (FcmPanel واحد تلو الآخر، نفس 14px padding) — **بلا هرمية بصرية على الإطلاق** (Heuristic: Visual Hierarchy / Jakob).
- زر Claim ارتفاعه **44px** (`fcm_button.dart` compact) — على الحدّ تمامًا لـ WCAG 2.5.8 (24x24 مساحة اللمس الفعلية عبر Padding تُقبل، لكن الـ chip `claimedRungs` و`_EquipToggle` أقصر وأصغر: ارتفاع تقديري ~20-22px بلا MaterialTapTargetSize — **مخالفة فعلية**).

**رأي مهني (أقولها بصراحة لأن المستخدم قال "مش كويس"):** إحساس "الشكل مش حلو" مصدره مش الألوان — مصدره **الرتابة البصرية** (نفس البانل ونفس الإيقاع 42 مرة)، **غياب حالات فارغة/تحميل هيكلية** (streak: `SizedBox(140)` صامتة؛ loading سبينر وسط الشاشة بلا هيكل)، **كثافة معلومات بلا تصنيف** (كل حاجة "مهم" = ولا حاجة)، و**الـ streak card دخيلة على Achievements** (هي action-now والباقي progress-long — اختلطت البنية).

---

## P0 — تصحيحات (خلل يمنع الاستخدام الصحيح)

### T-A1: أهداف اللمس (Touch targets) — Severity: HIGH (a11y قانوني)
- **المشكلة:** `_EquipToggle` في title_badge_showcase.dart و chip `claimedRungs` و`FcmCoinChip` ~20-22px ارتفاع، و`_DayPip` الغير اليوم (24x34) قابلة للنقر بصريًا لكنها ليست أهداف فعلية.
- **المطلوب:** لفّ كل عنصر interactable في `InkResponse`/`GestureDetector` بمساحة أدنى 48x48 منطقية (Material 3 `minimumSize`)، أو `SizedBox(width/height: 48)` + `Center`. الـ Equip toggle تحديدًا: hit area 48x48 مع الحفاظ على الحجم البصري 24.
- **Acceptance:** `flutter test` widget test يقيس `RenderBox.size` للـ hit area ≥ 48x48 لكل toggle/chip قابل للنقر في الشاشتين. RTL كذلك.

### T-A2: حالات التحميل والفراغ الهيكلية — Severity: HIGH (Heuristic: Recognition, Error prevention)
- **المشكلة:** Loading = سبينر وسط شاشة سوداء (فقدان السياق)، StreakCard أثناء التحميل = `SizedBox(140)` (قفزة layout عند الوصول)، ولا يوجد فراغ "أول موسم" مميّز في Achievements.
- **المطلوب:**
  - Skeletons: بانلات بنفس أبعاد الكتل الحقيقية (`FcmPanel` بتدرّج shimmer 800ms، `Curves.easeInOut`) تحافظ على الـ layout — منع القفز (CLS).
  - Empty state لـ Achievements عند fresh save: بانل واحد بـ icon `emoji_events` + سطر "أول فوز هيفتح أول إنجاز" + CTA غير مباشر.
  - `StreakCard` loading: نفس ارتفاع الهيدر (~64px) skeleton ثابت.
- **Acceptance:** golden/layout test: لا تغيّر في `height` الحاوية بين loading و data (±0px). نص الحالة الفارغة مترجم EN+AR.

---

## P1 — تحسينات هيكلية (الرتابة والكثافة — جوهر "مش كويس")

### T-B1: هيكلة Achievements — فلترة وتجميع — Severity: HIGH UX
- **المشكلة:** 42 كارت في سطر واحد طويل (تحتاج ~14 شاشة scroll)؛ اللاعب الجديد يفتقد 824 رنّة وكلها "قيد التقدم" — لا يوجد مسار "إيه اللي أقدر أعمله دلوقتي".
- **المطلوب:** Segmented control (Material 3) فوق القائمة بـ 3 حالات: **Claimable / In progress / Claimed** — default: Claimable عند وجوده وإلا In progress. الـ `_CategorySection` يبقى لكن يعرض الأقسام غير الفارغة فقط لكل فلتر.
- **Specs:** pill height 40، `FcmColors.surfaceHigh` للغير مفعل، gold للـ selected، نص من l10n جديد (`achFilterClaimable` / `achFilterInProgress` / `achFilterClaimed`) EN+AR.
- **Acceptance:** widget test: فلتر Claimed عند save فيه 3 claims يعرض 3 كروت فقط. الأقسام الفارغة لا تُرسم (لا headers يتيمة).

### T-B2: فصل الـ Streak عن قائمة الإنجازات — Severity: MEDIUM
- **المشكلة:** StreakCard = "action اليوم" فوق قائمة "تقدّم طويل" — إيقاعان مختلفان في شاشة واحدة، والبانل الذهب glow بيخطف عين المستخدم عن أول كارت claimable (Heuristic: Hierarchy).
- **المطلوب:** StreakCard يتحول لـ **bar مضغوط** (سطر واحد: 🔥 + "Day 3" + pips مصغّرة 5px + زر Claim inline) بارتفاع ≤72px — compact mode للـ widget الحالي. النسخة المفصّلة تظهر في bottom-sheet عند الضغط.
- **Acceptance:** ارتفاع الكارت في وضع closed ≤ 72px، والزر 48px hit area. RTL: النار والـ pips flip صحيح (نص Directionality test).

### T-B3: هرمية Profile — Severity: HIGH (السبب الثاني لـ "مش كويس")
- **المشكلة:** 7 كتل بنفس الوزن البصري — العين لا تعرف تبدأ منين؛ الـ stat panel (الأهم) شكله كـ silverware (الثانوي).
- **المطلوب (تدرّج الوزن بـ tokens موجودة):**
  - `_IdentityHeader`: يبقى كما هو (بانل + gold accent) — الوزن الأعلى.
  - `_StatPanel`: أبرز الأرقام — قيمة الـ tile تكبر 17→**20** (w900، `goldSoft`)، والـ stat الثانوي (goals against/clean sheets) ينقل لصف ثانوي مغروض مع غمق textDim؛ يستخدم `FcmColors.surfaceHigh` بدل `surface` لتمييزه عن باقي البانلات.
  - `_Silverware` + `_SeasonHistory`: يستخدما نمط list-row أفتح (بلا FcmPanel لكل صف — البانل للـ header فقط) — يقلل الازدحام البصري 40%.
- **Acceptance:** اختبار قياس: `Text.style.fontSize` للـ stat value = 20. عدد FcmPanel في شاشة Profile يقل من ~7+n إلى ≤ 5+n (فحص `find.byType`).

### T-B4: صفحة تفاصيل الكارت (expand) — Severity: MEDIUM
- **المشكلة:** الكارت الواحد مضغوط (desc بـ maxLines:2 ellipsis) — بيانات الرنّات التالية محجوبة؛ لكل كارت endless ladder الـ 24 رنّة غير مرئية أبدًا.
- **المطلوب:** الكارت قابل للتوسيع (AnimatedCrossFade أو `AnimatedSize` 200ms `easeOutCubic`): يعرض سلم الرنّات كقائمة mini (نفس نمط `_BadgeCell` في الـ showcase — أعيد استخدام `FcmBadgePainter`) + بداية النهاية. أول 3 رنّات مرئية دائمًا.
- **Acceptance:** اللمس على الكارت غير المُدّعى يوسّعه؛ golden test للحالة قبل/بعد. الزر/التوسيع 48px hit area.

---

## P2 — تشطيب (وضع، فرح، إشعارات)

### T-C1: تلميح "جاهز للمطالبة" — Severity: MEDIUM (قيمة المستخدم)
- **المطلوب:** Badge صغير على تبويب Achievements في الـ nav bar (dot ذهبي 8px) عند وجود ≥1 claimable. المصدر: `claimsProvider` + metrics — موجودان فعلًا، التكلفة دقيقة.
- **Acceptance:** عند claim خروج الـ dot (stream test). Dot بلا text (لا يضيف l10n).

### T-C2: micro-feedback للـ claim — Severity: LOW
- **المطلوب:** عند نجاح Claim: coin chip animation (scale 1→1.15→1، 250ms) + snackbar قياسي (نص l10n موجود بالفعل `achClaimedLabel`). عند الفشل: بانل danger inline — لا سبينر صامت.
- **Acceptance:** widget test: SnackBar يظهر بنص مترجم؛ لا exception عند claim سريع متتالي (reentrancy guard موجود — يُختبر).

### T-C3: تمرير سريع للـ history في Profile — Severity: LOW
- **المطلوب:** بعد 6 مواسم `_SeasonHistory` يتحول لـ "آخر 6" + زر "عرض الكل" يفتح bottom-sheet draggable بـ maxExtent 0.9.
- **Acceptance:** 10 مواسم → 6 صفوف + الزر؛ الـ sheet يعرض الـ 10.

---

## ما لا يُفعل (مقصود — قرارات مدروسة بشرحها)

- **لا نغيّر البالِت.** الألوان كلها تجتاز AA (36/36)؛ تغييرها الآن = كوست مرتفع بلا قيمة مستخدم — أولوية النتيجة للهيكل، مش اللون.
- **لا نضيف TabBar داخل Achievements.** الفلترة T-B1 بالـ segmented control أخف (nav داخلي ثاني يكسر نمط التطبيق ويزيد nesting بلا حاجة — قرار معماري مدروس).
- **لا نحوّل Profile لشاشة تعديل (edit name/crest).** حاجة مختلفة — تُطلب صريحة لو محتاجينها.

## الأرقام المرجعية (حسبتها بالكود — ليست تقديرًا)

| مقياس | قيمة |
|---|---|
| أزواج الألوان المفحوصة | 36 زوج — كلها PASS AA |
| كروت الإنجازات | 42 (10 أقسام، 824 رنّة مرئية) |
| ارتفاع زر Claim | 44px (compact) |
| عناصر interactable أقل من 48px | EquipToggle / claimedRungs chip / CoinChip |
| كتل Profile العمودية | 7 (بلا تمايز وزن) |

## ترتيب التنفيذ المقترح

1. **T-A1 + T-A2** (تصحيحات — يوم واحد)
2. **T-B1 + T-B2** (الأثر الأكبر على إحساس Achievements — 2-3 أيام)
3. **T-B3** (أثر Profile — 1-2 يوم)
4. **T-B4 + T-C\*** (تشطيب — 2 أيام)

كل مهمة مستقلة قابلة للـ merge منفصلة؛ الترتيب للاعتمادية البصرية فقط (T-B1 يبني على فهم فلترة claims موجودة في `claimsProvider`).
