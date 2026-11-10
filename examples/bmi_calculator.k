// BMI (Body Mass Index) calculator
// Demonstrates numerical computation in Krypton

// BMI = weight(kg) / height(m)^2
// Since Krypton uses integers only, we use weight in grams and height in cm
// BMI * 10 = (weight_kg * 10) / (height_m * height_m)
// Approximate: BMI = (weight_kg * 10000) / (height_cm * height_cm)

func calculateBMI(weightKg, heightCm) {
    // Returns BMI * 10 (i.e. 245 means 24.5)
    emit (weightKg * 100000) / (heightCm * heightCm)
}

func bmiCategory(bmi10) {
    if bmi10 < 185 {
        emit "Underweight"
    }
    if bmi10 < 250 {
        emit "Normal"
    }
    if bmi10 < 300 {
        emit "Overweight"
    }
    emit "Obese"
}

func formatBMI(bmi10) {
    let whole = bmi10 / 10
    let frac = bmi10 % 10
    emit "" + whole + "." + frac
}

just run {
    print("BMI Calculator")
    print("==============")
    print("")

    // Sample data: weight(kg), height(cm)
    print("Sample calculations:")
    print("")
    print("Weight(kg)  Height(cm)  BMI      Category")
    print("----------  ----------  -------  -----------")

    let weights = "50,60,70,75,80,90,100,110"
    let heights = "160,165,170,175,180,175,180,185"
    let total = count(weights)
    let i = 0
    while i < total {
        let w = toInt(split(weights, i))
        let h = toInt(split(heights, i))
        let bmi = calculateBMI(w, h)
        let cat = bmiCategory(bmi)

        let wStr = "" + w
        while len(wStr) < 10 { wStr = wStr + " " }
        let hStr = "" + h
        while len(hStr) < 10 { hStr = hStr + " " }
        let bStr = formatBMI(bmi)
        while len(bStr) < 8 { bStr = bStr + " " }

        print(wStr + "  " + hStr + "  " + bStr + " " + cat)
        i += 1
    }

    print("")
    print("BMI Ranges:")
    print("  < 18.5  : Underweight")
    print("  18.5-24.9: Normal")
    print("  25.0-29.9: Overweight")
    print("  >= 30.0 : Obese")
    emit "ok"
}
