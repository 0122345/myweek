# My Week

Your week of classes in one app. It keeps every day in order, adds up your hours, and warns you before two courses collide.

## Screens

- **Week** ([lib/week.dart](lib/week.dart)): the week's total, day chips Mon–Fri, and the chosen day's courses in start-time order with the day's total. Clashing courses are red and say *Clashes with …*. Tap a course to edit it, and use the bin icon to delete it (after an *Are you sure?* dialog).
- **Clashes** tab: every clash in the week. Tap one to jump to that day.
- **Add / edit course** ([lib/course_form.dart](lib/course_form.dart)): name, day, and start and end times typed as `08:00`. A circular clock lets you drag the times instead; it writes into the same text fields, so the same `HH:MM` checks apply.

Packages: [google_nav_bar](https://pub.dev/packages/google_nav_bar) for the Week / Clashes bottom bar, and [progressive_time_picker](https://pub.dev/packages/progressive_time_picker) for the clock.

All the rules (parsing, sorting, clashes, totals, free time) live in [lib/course.dart](lib/course.dart) and are tested in [test/widget_test.dart](test/widget_test.dart).

## Sample data

| Day | Courses |
|---|---|
| Monday | Maths 08:00–10:00, Physics 10:00–11:30 → 3h 30m, no clash |
| Tuesday | Chemistry 09:00–11:00 and Biology 10:30–12:00 **clash**, English 14:00–15:00 |
| Wednesday | *No classes on Wednesday* |
| Thursday | History 13:00–15:00 and Programming 08:30–10:00, entered out of order but shown sorted |
| Friday | empty |

## 🤔 Think

**Write your clash condition in plain words. Why `<` and not `<=`?**

Two courses on the same day clash when the first one starts before the second one ends **and** the second one starts before the first one ends:

```dart
a.start < b.end && b.start < a.end
```

We use `<` because a course ending at 11:00 and another starting at 11:00 only touch; they don't overlap. You walk out of one room and into the next. With `<=`, the test `11:00 <= 11:00` would be true and back-to-back courses would wrongly turn red.

**Why is it easier to store times as minutes than as text like `08:30`?**

A number can be compared and subtracted directly. `510 < 600` and `600 - 510 = 90` minutes just work. Text can't do this: you can't subtract `"08:30"` from `"10:00"`, and comparing strings only works by accident when every time is zero-padded (`"9:00" > "10:00"` as text). So we parse the text once when the user types it, which is also when we catch bad input like `8h`, `25:00` or `10:75`. All the maths runs on minutes, and we turn minutes back into `HH:MM` only for display.

## ⚡ Push further (done)

- Free time between classes is shown inline, e.g. *Free: 11:30–14:00*.
- The **Clashes** tab (with a count, e.g. *Clashes (1)*) lists every clash in the week. Tap one to jump to that day.

## Run

```
flutter run
flutter test
```
