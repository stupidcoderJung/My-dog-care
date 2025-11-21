# Prompt: Care Calendar UI Implementation

**Goal**: Build the UI for the Care Calendar using SwiftUI.

**Context**:
Users need a calendar view to see and add care events.

**Task**:
1.  Create `Views/CareCalendarView.swift`.
2.  Create `Views/AddCareEventSheet.swift`.

**Requirements**:
- **CareCalendarView**:
    - Use a Calendar library (like `FSCalendar` via UIViewRepresentable) OR a native SwiftUI `LazyVGrid` implementation for the month view.
    - Show a list of events for the selected date below the calendar.
    - Include a Floating Action Button (+) to open the add sheet.
    - Fetch `CareEvent`s using `@Query`.
- **AddCareEventSheet**:
    - Form with:
        - DatePicker
        - Picker (Category)
        - TextField (Title)
        - TextField (Value - numeric keyboard if applicable)
        - TextEditor (Notes)
    - "Save" button to insert into `modelContext`.

**Instructions for AI**:
- Focus on a clean, modern design matching the app's aesthetic.
- Handle the `modelContext` insertion properly.
- Ensure the calendar updates when events are added.
