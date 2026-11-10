// task_manager.k — demonstrates structs, try/catch, interpolation, for-in

struct Task {
    let id
    let title
    let done
    let priority
}

func createTask(id, title, priority) {
    emit Task { id: id, title: title, done: "0", priority: priority }
}

func taskSummary(t) {
    let status = t.done == "1" ? "✓" : "○"
    emit `[{status}] #{t.id} {t.title} (priority: {t.priority})`
}

func completTask(t) {
    t.done = "1"
    emit t
}

func filterByPriority(tasks, p) {
    let result = ""
    for task in tasks {
        // tasks stored as IDs, lookup by convention
    }
    emit result
}

just run {
    // Create some tasks
    let t1 = createTask("1", "Write compiler", "high")
    let t2 = createTask("2", "Add tests", "high")
    let t3 = createTask("3", "Update docs", "medium")
    let t4 = createTask("4", "Fix bug #42", "low")

    print("=== Task Manager ===")
    print(taskSummary(t1))
    print(taskSummary(t2))
    print(taskSummary(t3))
    print(taskSummary(t4))

    // Complete a task
    t1 = completTask(t1)
    print("")
    print("After completing task 1:")
    print(taskSummary(t1))

    // Exception handling for invalid operations
    try {
        let badPriority = "critical"
        match badPriority {
            "high"   { print("high priority") }
            "medium" { print("medium priority") }
            "low"    { print("low priority") }
            else     { throw `unknown priority: {badPriority}` }
        }
    } catch e {
        print(`Error: {e}`)
    }

    // Summary stats
    let total = 4
    let done = 1
    print("")
    print(`Progress: {done}/{total} tasks complete`)
}
