import SwiftUI
import SwiftData

struct CareCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CareEvent.date, order: .forward) private var allEvents: [CareEvent]

    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var isAddSheetPresented = false

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Month Navigation
                    HStack {
                        Button(action: { changeMonth(by: -1) }) {
                            Image(systemName: "chevron.left")
                                .padding()
                        }
                        
                        Spacer()
                        
                        Text(monthYearString(from: currentMonth))
                            .font(.title2.bold())
                        
                        Spacer()
                        
                        Button(action: { changeMonth(by: 1) }) {
                            Image(systemName: "chevron.right")
                                .padding()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                    // Days of Week Header
                    HStack {
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(day)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.bottom, 10)

                    // Calendar Grid
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(daysInMonth(), id: \.self) { date in
                            if let date = date {
                                DayCell(date: date, isSelected: calendar.isDate(date, inSameDayAs: selectedDate), hasEvents: hasEvents(on: date))
                                    .onTapGesture {
                                        selectedDate = date
                                    }
                            } else {
                                Text("")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)

                    Divider()

                    // Events List
                    List {
                        if eventsForSelectedDate.isEmpty {
                            ContentUnavailableView("No Events", systemImage: "calendar.badge.exclamationmark", description: Text("No care events for this day."))
                        } else {
                            ForEach(eventsForSelectedDate) { event in
                                CareEventRow(event: event)
                            }
                            .onDelete(perform: deleteEvents)
                        }
                    }
                    .listStyle(.plain)
                }

                // Floating Action Button
                Button(action: { isAddSheetPresented = true }) {
                    Image(systemName: "plus")
                        .font(.title.weight(.semibold))
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                        .shadow(radius: 4, x: 0, y: 4)
                }
                .padding()
            }
            .navigationTitle("Care Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isAddSheetPresented) {
                AddCareEventSheet()
            }
        }
    }

    // MARK: - Helpers

    private var eventsForSelectedDate: [CareEvent] {
        allEvents.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private func hasEvents(on date: Date) -> Bool {
        allEvents.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        // Calendar weekday is 1-based (Sun=1). Adjust for array index.
        let offsetDays = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: offsetDays)

        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }

        return days
    }

    private func deleteEvents(at offsets: IndexSet) {
        for index in offsets {
            let event = eventsForSelectedDate[index]
            modelContext.delete(event)
        }
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let hasEvents: Bool
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: date))")
                .font(.body)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.accentColor : Color.clear)
                .clipShape(Circle())

            if hasEvents {
                Circle()
                    .fill(isSelected ? .white : Color.accentColor)
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

struct CareEventRow: View {
    let event: CareEvent

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                if let notes = event.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(event.category.rawValue.capitalized)
                    .font(.caption2)
                    .padding(4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                
                if let value = event.value {
                    Text(String(format: "%.1f", value))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
