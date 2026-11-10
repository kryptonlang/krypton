// Show how various units add up to a year.

just run {
    let secPerMin = 60
    let minPerHour = 60
    let hourPerDay = 24
    let dayPerYear = 365

    let secPerHour = secPerMin * minPerHour
    let secPerDay  = secPerHour * hourPerDay
    let secPerYear = secPerDay * dayPerYear

    print("Time unit breakdown")
    print("===================")
    print("seconds per minute: " + secPerMin)
    print("seconds per hour:   " + secPerHour)
    print("seconds per day:    " + secPerDay)
    print("seconds per year:   " + secPerYear)
    print("")

    print("Comparisons:")
    print("  1 day  = " + (secPerDay  / secPerMin) + " minutes")
    print("  1 year = " + (secPerYear / secPerHour) + " hours")
    print("  1 year = " + (secPerYear / secPerDay)  + " days")
    print("")

    let yearsAlive = 30
    let totalSec = yearsAlive * secPerYear
    print("If you've been alive for " + yearsAlive + " years, you've experienced:")
    print("  " + totalSec + " seconds")
    print("  " + (totalSec / secPerHour) + " hours")
}
