//
//  FoodVectorIcons.swift
//  CookieNotes
//
//  FoodIconView loads sliced FoodIllustrations bitmaps from the contact sheet.
//  FoodVectorIcon remains as a fallback for any missing asset names.
//

import SwiftUI
import UIKit

struct FoodVectorIcon: View {
    let id: String

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                artwork
                    .frame(width: s, height: s)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        switch id {
        case "tomatoes_vine", "tomato": TomatoArt()
        case "avocado": AvocadoArt()
        case "mushrooms": MushroomArt()
        case "chili_pepper": ChiliArt()
        case "bell_pepper": BellPepperArt()
        case "corn": CornArt()
        case "eggplant": EggplantArt()
        case "carrots_radish", "carrot": CarrotArt()
        case "lettuce": LettuceArt()
        case "berry_bowl", "berries": BerryBowlArt()
        case "bananas_oranges", "banana": BananaArt()
        case "salmon", "fish": SalmonArt()
        case "roast_chicken", "chicken": ChickenArt()
        case "burger": BurgerArt()
        case "eggs_bowl", "eggs", "egg": EggsArt()
        case "cheese_wedge", "cheese": CheeseArt()
        case "rice_bowl", "rice": RiceBowlArt()
        case "bread_loaf", "bread": BreadArt()
        case "spaghetti", "pasta": SpaghettiArt()
        case "pancakes": PancakeArt()
        case "salad_bowl", "salad": SaladArt()
        case "plated_meal": PlatedMealArt()
        case "soup_bowl", "soup": SoupArt()
        case "taco": TacoArt()
        case "pepperoni_pizza", "pizza": PizzaArt()
        case "cupcake": CupcakeArt()
        case "cookie": CookieArt()
        case "chocolate_bar", "chocolate": ChocolateArt()
        case "donut": DonutArt()
        case "ice_cream": IceCreamArt()
        case "honey_jar", "honey": HoneyArt()
        case "coffee_cup", "coffee": CoffeeArt()
        case "smoothie": SmoothieArt()
        case "cutting_board": BoardArt()
        case "chef_knife": KnifeArt()
        case "mixing_bowl": WhiskBowlArt()
        case "measuring_cup": MeasuringCupArt()
        case "rolling_pin": RollingPinArt()
        case "oven_mitt": MittArt()
        case "kitchen_scale": ScaleArt()
        case "cat_vegetables": CatVegArt()
        case "cat_fruits": CatFruitArt()
        case "cat_meat_seafood": CatMeatArt()
        case "cat_dairy_eggs": CatDairyArt()
        case "cat_grains": CatGrainArt()
        case "cat_pantry": CatPantryArt()
        case "cat_sweets": CupcakeArt()
        case "cat_drinks": SmoothieArt()
        default:
            FallbackArt()
        }
    }
}

// MARK: - Shared helpers

private struct Bowl<Content: View>: View {
    var color: Color = Color(red: 0.45, green: 0.72, blue: 0.92)
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Ellipse()
                .fill(color.opacity(0.35))
                .frame(width: 78, height: 18)
                .offset(y: 28)
            Capsule()
                .fill(color)
                .frame(width: 84, height: 34)
                .offset(y: 18)
            content()
                .offset(y: -2)
        }
        .frame(width: 100, height: 100)
    }
}

private struct FallbackArt: View {
    var body: some View {
        ZStack {
            Circle().fill(AppTheme.goldenYellow.opacity(0.55))
            Image(systemName: "fork.knife")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(AppTheme.burntOrange)
        }
        .frame(width: 100, height: 100)
    }
}

// MARK: - Produce

private struct TomatoArt: View {
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(AppTheme.tomatoRed)
                    .overlay(Circle().stroke(AppTheme.nearBlack.opacity(0.15), lineWidth: 1))
                    .frame(width: 34, height: 34)
                    .offset(x: CGFloat(i - 1) * 18, y: CGFloat(i == 1 ? -6 : 4))
            }
            Capsule().fill(AppTheme.leafGreen).frame(width: 28, height: 8).offset(y: -22)
            Capsule().fill(AppTheme.leafGreen).frame(width: 8, height: 16).offset(y: -28)
        }
        .frame(width: 100, height: 100)
    }
}

private struct AvocadoArt: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(AppTheme.leafGreen)
                .frame(width: 42, height: 64)
                .rotationEffect(.degrees(-18))
                .offset(x: -16)
            Capsule()
                .fill(Color(red: 0.72, green: 0.86, blue: 0.35))
                .frame(width: 40, height: 60)
                .overlay(
                    Circle()
                        .fill(AppTheme.warmBrown)
                        .frame(width: 16, height: 16)
                )
                .rotationEffect(.degrees(12))
                .offset(x: 14)
        }
        .frame(width: 100, height: 100)
    }
}

private struct MushroomArt: View {
    var body: some View {
        HStack(spacing: 6) {
            mushroom(size: 0.85)
            mushroom(size: 1.0)
            mushroom(size: 0.7)
        }
        .frame(width: 100, height: 100)
    }

    private func mushroom(size: CGFloat) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(red: 0.93, green: 0.88, blue: 0.78))
                .frame(width: 28 * size, height: 18 * size)
            Capsule()
                .fill(Color.white)
                .frame(width: 10 * size, height: 18 * size)
        }
    }
}

private struct ChiliArt: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(AppTheme.tomatoRed)
                .frame(width: 22, height: 70)
                .rotationEffect(.degrees(28))
            Capsule()
                .fill(AppTheme.leafGreen)
                .frame(width: 10, height: 18)
                .offset(x: -18, y: -28)
        }
        .frame(width: 100, height: 100)
    }
}

private struct BellPepperArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.leafGreen)
                .frame(width: 48, height: 56)
            Capsule().fill(AppTheme.leafGreen.opacity(0.85)).frame(width: 14, height: 16).offset(y: -30)
            Circle().fill(Color.white.opacity(0.35)).frame(width: 12, height: 12).offset(x: -10, y: -8)
        }
        .frame(width: 100, height: 100)
    }
}

private struct CornArt: View {
    var body: some View {
        ZStack {
            Capsule().fill(AppTheme.leafGreen).frame(width: 36, height: 70).rotationEffect(.degrees(-8))
            Capsule().fill(AppTheme.goldenYellow).frame(width: 26, height: 58)
            VStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(spacing: 3) {
                        Circle().fill(AppTheme.brightOrange.opacity(0.7)).frame(width: 5, height: 5)
                        Circle().fill(AppTheme.brightOrange.opacity(0.7)).frame(width: 5, height: 5)
                    }
                }
            }
        }
        .frame(width: 100, height: 100)
    }
}

private struct EggplantArt: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.45, green: 0.22, blue: 0.55))
                .frame(width: 40, height: 68)
                .rotationEffect(.degrees(18))
            Capsule().fill(AppTheme.leafGreen).frame(width: 18, height: 14).offset(x: -10, y: -30)
        }
        .frame(width: 100, height: 100)
    }
}

private struct CarrotArt: View {
    var body: some View {
        ZStack {
            Capsule().fill(AppTheme.brightOrange).frame(width: 22, height: 64).rotationEffect(.degrees(20))
            Capsule().fill(AppTheme.burntOrange).frame(width: 18, height: 54).rotationEffect(.degrees(-12)).offset(x: -16, y: 4)
            Capsule().fill(AppTheme.leafGreen).frame(width: 8, height: 22).offset(x: 8, y: -34)
            Capsule().fill(AppTheme.leafGreen).frame(width: 8, height: 18).offset(x: -18, y: -28)
        }
        .frame(width: 100, height: 100)
    }
}

private struct LettuceArt: View {
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(i % 2 == 0 ? AppTheme.leafGreen : Color(red: 0.55, green: 0.78, blue: 0.35))
                    .frame(width: 22, height: 48)
                    .rotationEffect(.degrees(Double(i) * 28 - 56))
            }
        }
        .frame(width: 100, height: 100)
    }
}

private struct BerryBowlArt: View {
    var body: some View {
        Bowl {
            HStack(spacing: 4) {
                Circle().fill(AppTheme.tomatoRed).frame(width: 16, height: 16)
                Circle().fill(AppTheme.berryBlue).frame(width: 14, height: 14)
                Circle().fill(Color(red: 0.75, green: 0.25, blue: 0.45)).frame(width: 15, height: 15)
            }
            .offset(y: 4)
        }
    }
}

private struct BananaArt: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(AppTheme.goldenYellow)
                .frame(width: 22, height: 70)
                .rotationEffect(.degrees(-35))
                .offset(x: -8)
            Circle()
                .fill(AppTheme.brightOrange)
                .frame(width: 36, height: 36)
                .offset(x: 18, y: 10)
        }
        .frame(width: 100, height: 100)
    }
}

// MARK: - Proteins / dairy / grains

private struct SalmonArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.95, green: 0.55, blue: 0.45))
                .frame(width: 70, height: 42)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.35, green: 0.55, blue: 0.75))
                .frame(width: 14, height: 42)
                .offset(x: -28)
        }
        .frame(width: 100, height: 100)
    }
}

private struct ChickenArt: View {
    var body: some View {
        ZStack {
            Ellipse().fill(AppTheme.brightOrange).frame(width: 70, height: 48)
            Circle().fill(AppTheme.goldenYellow).frame(width: 28, height: 28).offset(x: 22, y: -18)
            Capsule().fill(AppTheme.burntOrange).frame(width: 10, height: 18).offset(x: 34, y: -28)
        }
        .frame(width: 100, height: 100)
    }
}

private struct BurgerArt: View {
    var body: some View {
        VStack(spacing: 2) {
            Capsule().fill(AppTheme.goldenYellow).frame(width: 70, height: 18)
            Capsule().fill(AppTheme.leafGreen).frame(width: 66, height: 8)
            Capsule().fill(AppTheme.tomatoRed).frame(width: 62, height: 8)
            Capsule().fill(AppTheme.warmBrown).frame(width: 68, height: 14)
            Capsule().fill(AppTheme.goldenYellow).frame(width: 70, height: 16)
        }
        .frame(width: 100, height: 100)
    }
}

private struct EggsArt: View {
    var body: some View {
        Bowl(color: AppTheme.berryBlue) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    Ellipse()
                        .fill(Color(red: 0.86, green: 0.72, blue: 0.48))
                        .frame(width: 18, height: 24)
                }
            }
            .offset(y: 2)
        }
    }
}

private struct CheeseArt: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 20, y: 70))
                path.addLine(to: CGPoint(x: 80, y: 70))
                path.addLine(to: CGPoint(x: 55, y: 25))
                path.closeSubpath()
            }
            .fill(AppTheme.goldenYellow)
            Circle().fill(AppTheme.brightOrange.opacity(0.45)).frame(width: 10, height: 10).offset(x: -4, y: 6)
            Circle().fill(AppTheme.brightOrange.opacity(0.45)).frame(width: 8, height: 8).offset(x: 10, y: 14)
        }
        .frame(width: 100, height: 100)
    }
}

private struct RiceBowlArt: View {
    var body: some View {
        Bowl(color: Color(red: 0.25, green: 0.4, blue: 0.7)) {
            Capsule()
                .fill(Color.white)
                .frame(width: 60, height: 28)
                .offset(y: 2)
            Capsule().fill(AppTheme.leafGreen).frame(width: 18, height: 6).offset(x: 10, y: -4)
        }
    }
}

private struct BreadArt: View {
    var body: some View {
        ZStack {
            Capsule().fill(AppTheme.brightOrange).frame(width: 78, height: 36)
            Capsule().fill(AppTheme.goldenYellow).frame(width: 70, height: 28)
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(AppTheme.warmBrown.opacity(0.35))
                    .frame(width: 2, height: 22)
                    .offset(x: CGFloat(i - 1) * 16)
            }
        }
        .frame(width: 100, height: 100)
    }
}

private struct SpaghettiArt: View {
    var body: some View {
        Bowl {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(AppTheme.goldenYellow)
                    .frame(width: 54, height: 5)
                    .rotationEffect(.degrees(Double(i) * 12 - 18))
                    .offset(y: CGFloat(i) * 3 - 4)
            }
            Circle().fill(AppTheme.tomatoRed).frame(width: 28, height: 28).offset(y: 2)
        }
    }
}

private struct PancakeArt: View {
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(AppTheme.goldenYellow)
                    .overlay(Capsule().stroke(AppTheme.burntOrange.opacity(0.25), lineWidth: 1))
                    .frame(width: 70 - CGFloat(i), height: 16)
                    .offset(y: CGFloat(i) * 10 - 8)
            }
            Circle().fill(AppTheme.tomatoRed).frame(width: 10, height: 10).offset(x: -8, y: -22)
            Circle().fill(AppTheme.berryBlue).frame(width: 9, height: 9).offset(x: 6, y: -20)
        }
        .frame(width: 100, height: 100)
    }
}

// MARK: - Dishes

private struct SaladArt: View {
    var body: some View {
        Bowl {
            Capsule().fill(AppTheme.leafGreen).frame(width: 50, height: 14).offset(y: -2)
            Circle().fill(AppTheme.tomatoRed).frame(width: 12, height: 12).offset(x: -14, y: 6)
            Circle().fill(Color(red: 0.95, green: 0.8, blue: 0.35)).frame(width: 12, height: 12).offset(x: 12, y: 4)
        }
    }
}

private struct PlatedMealArt: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.white).frame(width: 78, height: 78)
            Circle().stroke(AppTheme.warmBrown.opacity(0.2), lineWidth: 3).frame(width: 78, height: 78)
            Capsule().fill(AppTheme.burntOrange).frame(width: 34, height: 20).offset(y: -8)
            Capsule().fill(AppTheme.leafGreen).frame(width: 28, height: 14).offset(x: -16, y: 12)
            Circle().fill(AppTheme.goldenYellow).frame(width: 16, height: 16).offset(x: 16, y: 12)
        }
        .frame(width: 100, height: 100)
    }
}

private struct SoupArt: View {
    var body: some View {
        Bowl(color: AppTheme.berryBlue) {
            Capsule()
                .fill(AppTheme.brightOrange)
                .frame(width: 58, height: 24)
                .offset(y: 4)
            Capsule().fill(AppTheme.leafGreen).frame(width: 16, height: 6).offset(x: 8, y: -2)
        }
    }
}

private struct TacoArt: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(AppTheme.goldenYellow)
                .frame(width: 76, height: 40)
                .rotationEffect(.degrees(-8))
            Capsule().fill(AppTheme.leafGreen).frame(width: 50, height: 10).offset(y: -2)
            Capsule().fill(AppTheme.warmBrown).frame(width: 46, height: 10).offset(y: 6)
            Circle().fill(AppTheme.tomatoRed).frame(width: 10, height: 10).offset(x: 12, y: 0)
        }
        .frame(width: 100, height: 100)
    }
}

private struct PizzaArt: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 50, y: 18))
                path.addLine(to: CGPoint(x: 82, y: 78))
                path.addLine(to: CGPoint(x: 18, y: 78))
                path.closeSubpath()
            }
            .fill(AppTheme.goldenYellow)
            Path { path in
                path.move(to: CGPoint(x: 50, y: 28))
                path.addLine(to: CGPoint(x: 72, y: 72))
                path.addLine(to: CGPoint(x: 28, y: 72))
                path.closeSubpath()
            }
            .fill(AppTheme.tomatoRed.opacity(0.85))
            Circle().fill(AppTheme.burntOrange).frame(width: 10, height: 10).offset(y: 8)
            Circle().fill(AppTheme.burntOrange).frame(width: 9, height: 9).offset(x: -10, y: 16)
        }
        .frame(width: 100, height: 100)
    }
}

// MARK: - Sweets / drinks / tools

private struct CupcakeArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.warmBrown)
                .frame(width: 40, height: 28)
                .offset(y: 22)
            Capsule().fill(Color(red: 0.95, green: 0.55, blue: 0.7)).frame(width: 56, height: 34).offset(y: 2)
            Circle().fill(AppTheme.tomatoRed).frame(width: 12, height: 12).offset(y: -14)
        }
        .frame(width: 100, height: 100)
    }
}

private struct CookieArt: View {
    var body: some View {
        ZStack {
            Circle().fill(AppTheme.brightOrange).frame(width: 64, height: 64)
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(AppTheme.warmBrown)
                    .frame(width: 7, height: 7)
                    .offset(
                        x: cos(Double(i) / 6 * .pi * 2) * 16,
                        y: sin(Double(i) / 6 * .pi * 2) * 16
                    )
            }
        }
        .frame(width: 100, height: 100)
    }
}

private struct ChocolateArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.warmBrown)
                .frame(width: 64, height: 40)
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 3).stroke(AppTheme.goldenYellow.opacity(0.4), lineWidth: 1)
                            .frame(width: 16, height: 14)
                    }
                }
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 3).stroke(AppTheme.goldenYellow.opacity(0.4), lineWidth: 1)
                            .frame(width: 16, height: 14)
                    }
                }
            }
        }
        .frame(width: 100, height: 100)
    }
}

private struct DonutArt: View {
    var body: some View {
        ZStack {
            Circle().fill(AppTheme.goldenYellow).frame(width: 64, height: 64)
            Circle().fill(Color(red: 0.95, green: 0.55, blue: 0.7)).frame(width: 56, height: 56)
            Circle().fill(AppTheme.cream).frame(width: 22, height: 22)
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill([AppTheme.berryBlue, AppTheme.tomatoRed, AppTheme.goldenYellow][i % 3])
                    .frame(width: 4, height: 10)
                    .offset(y: -20)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
        .frame(width: 100, height: 100)
    }
}

private struct IceCreamArt: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: -6) {
                Circle().fill(Color(red: 0.95, green: 0.55, blue: 0.7)).frame(width: 22, height: 22)
                Circle().fill(Color.white).frame(width: 22, height: 22)
                Circle().fill(AppTheme.berryBlue).frame(width: 22, height: 22)
            }
            Path { path in
                path.move(to: CGPoint(x: 20, y: 0))
                path.addLine(to: CGPoint(x: 40, y: 0))
                path.addLine(to: CGPoint(x: 30, y: 36))
                path.closeSubpath()
            }
            .fill(AppTheme.brightOrange)
            .frame(width: 60, height: 36)
        }
        .frame(width: 100, height: 100)
    }
}

private struct HoneyArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.goldenYellow)
                .frame(width: 40, height: 48)
                .offset(y: 8)
            Capsule().fill(AppTheme.warmBrown).frame(width: 44, height: 10).offset(y: -14)
            Capsule().fill(AppTheme.warmBrown).frame(width: 8, height: 36).rotationEffect(.degrees(28)).offset(x: 22, y: -8)
        }
        .frame(width: 100, height: 100)
    }
}

private struct CoffeeArt: View {
    var body: some View {
        ZStack {
            Capsule().fill(Color.white).frame(width: 54, height: 40).offset(y: 8)
            Capsule().fill(AppTheme.warmBrown).frame(width: 46, height: 28).offset(y: 6)
            Capsule().stroke(AppTheme.warmBrown.opacity(0.5), lineWidth: 3).frame(width: 16, height: 20).offset(x: 30, y: 6)
            Capsule().fill(AppTheme.nearBlack.opacity(0.12)).frame(width: 8, height: 16).offset(x: -8, y: -18)
        }
        .frame(width: 100, height: 100)
    }
}

private struct SmoothieArt: View {
    var body: some View {
        ZStack {
            Capsule().fill(Color(red: 0.55, green: 0.3, blue: 0.65)).frame(width: 34, height: 64)
            Capsule().fill(Color.white.opacity(0.25)).frame(width: 10, height: 40).offset(x: -8)
            Capsule().fill(AppTheme.goldenYellow).frame(width: 4, height: 50).offset(x: 6, y: -20)
            Circle().fill(AppTheme.tomatoRed).frame(width: 12, height: 12).offset(y: -34)
        }
        .frame(width: 100, height: 100)
    }
}

private struct BoardArt: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(AppTheme.warmBrown)
            .frame(width: 70, height: 48)
            .overlay(
                Capsule().fill(AppTheme.brightOrange.opacity(0.5)).frame(width: 14, height: 8).offset(x: 24)
            )
            .frame(width: 100, height: 100)
    }
}

private struct KnifeArt: View {
    var body: some View {
        ZStack {
            Capsule().fill(Color(red: 0.75, green: 0.78, blue: 0.82)).frame(width: 18, height: 58).offset(y: -8)
            Capsule().fill(AppTheme.berryBlue).frame(width: 16, height: 28).offset(y: 28)
        }
        .rotationEffect(.degrees(-20))
        .frame(width: 100, height: 100)
    }
}

private struct WhiskBowlArt: View {
    var body: some View {
        Bowl(color: AppTheme.berryBlue) {
            Capsule().fill(AppTheme.warmBrown).frame(width: 6, height: 40).rotationEffect(.degrees(28)).offset(x: 8, y: -10)
        }
    }
}

private struct MeasuringCupArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.75, green: 0.88, blue: 0.95).opacity(0.9))
                .frame(width: 40, height: 52)
            Capsule().fill(AppTheme.tomatoRed).frame(width: 28, height: 4).offset(y: -6)
            Capsule().fill(AppTheme.tomatoRed).frame(width: 28, height: 4).offset(y: 6)
        }
        .frame(width: 100, height: 100)
    }
}

private struct RollingPinArt: View {
    var body: some View {
        HStack(spacing: 0) {
            Capsule().fill(AppTheme.warmBrown).frame(width: 14, height: 12)
            Capsule().fill(AppTheme.brightOrange).frame(width: 58, height: 22)
            Capsule().fill(AppTheme.warmBrown).frame(width: 14, height: 12)
        }
        .frame(width: 100, height: 100)
    }
}

private struct MittArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.tomatoRed)
                .frame(width: 48, height: 58)
            Circle().fill(Color.white.opacity(0.85)).frame(width: 8, height: 8).offset(x: -8, y: -8)
            Circle().fill(Color.white.opacity(0.85)).frame(width: 8, height: 8).offset(x: 8, y: 4)
        }
        .frame(width: 100, height: 100)
    }
}

private struct ScaleArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.tomatoRed)
                .frame(width: 64, height: 36)
                .offset(y: 12)
            Circle().fill(Color.white).frame(width: 28, height: 28).offset(y: -8)
            Capsule().fill(AppTheme.nearBlack).frame(width: 2, height: 10).offset(y: -10)
        }
        .frame(width: 100, height: 100)
    }
}

// MARK: - Category composites

private struct CatVegArt: View {
    var body: some View {
        Bowl {
            HStack(spacing: 2) {
                Capsule().fill(AppTheme.brightOrange).frame(width: 10, height: 22)
                Capsule().fill(AppTheme.leafGreen).frame(width: 16, height: 18)
                Circle().fill(AppTheme.tomatoRed).frame(width: 14, height: 14)
            }
            .offset(y: 2)
        }
    }
}

private struct CatFruitArt: View {
    var body: some View {
        ZStack {
            Circle().fill(AppTheme.tomatoRed).frame(width: 28, height: 28).offset(x: -16, y: 6)
            Capsule().fill(AppTheme.goldenYellow).frame(width: 16, height: 40).rotationEffect(.degrees(-30)).offset(x: 8, y: 0)
            Circle().fill(AppTheme.berryBlue).frame(width: 12, height: 12).offset(x: 22, y: 16)
            Circle().fill(AppTheme.berryBlue).frame(width: 10, height: 10).offset(x: 14, y: 22)
        }
        .frame(width: 100, height: 100)
    }
}

private struct CatMeatArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.tomatoRed)
                .frame(width: 40, height: 28)
                .offset(x: -14)
            Capsule()
                .fill(AppTheme.berryBlue)
                .frame(width: 44, height: 22)
                .rotationEffect(.degrees(-20))
                .offset(x: 16, y: 8)
        }
        .frame(width: 100, height: 100)
    }
}

private struct CatDairyArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white)
                .frame(width: 28, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.berryBlue)
                        .frame(width: 20, height: 14)
                        .offset(y: -6)
                )
                .offset(x: -16)
            CheeseArt().scaleEffect(0.55).offset(x: 18, y: 6)
        }
        .frame(width: 100, height: 100)
    }
}

private struct CatGrainArt: View {
    var body: some View {
        Bowl {
            Capsule().fill(AppTheme.goldenYellow).frame(width: 54, height: 22).offset(y: 4)
            Capsule().fill(AppTheme.brightOrange).frame(width: 6, height: 28).offset(x: -18, y: -10)
            Capsule().fill(AppTheme.brightOrange).frame(width: 6, height: 28).offset(x: 18, y: -10)
        }
    }
}

private struct CatPantryArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.berryBlue)
                .frame(width: 36, height: 48)
            Capsule().fill(Color(red: 0.95, green: 0.55, blue: 0.7)).frame(width: 28, height: 14).offset(y: -4)
            Circle().fill(AppTheme.warmBrown).frame(width: 14, height: 14).offset(x: 22, y: 18)
        }
        .frame(width: 100, height: 100)
    }
}

// MARK: - Shared view used by forms

struct FoodIconView: View {
    let iconID: String
    var size: CGFloat = 48
    private let extraIconIDs: [String]

    init(iconID: String, size: CGFloat = 48) {
        self.iconID = iconID
        self.size = size
        self.extraIconIDs = []
    }

    init(iconIDs: [String], size: CGFloat = 48) {
        let cleaned = iconIDs.filter { !$0.isEmpty }
        self.iconID = cleaned.first ?? ""
        self.size = size
        self.extraIconIDs = Array(cleaned.dropFirst())
    }

    var body: some View {
        if extraIconIDs.isEmpty {
            singleIcon(iconID, size: size)
        } else {
            DishCoverView(iconIDs: [iconID] + extraIconIDs, size: size)
        }
    }

    @ViewBuilder
    private func singleIcon(_ id: String, size: CGFloat) -> some View {
        Group {
            if id.isEmpty {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(AppTheme.leafGreen)
            } else if Self.hasAsset(id) {
                Image(id)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                FoodVectorIcon(id: id)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static let assetLookup = LockedCache<String, Bool>()

    /// `UIImage(named:)` on every render walks the asset catalog; remember the answer per id.
    private static func hasAsset(_ id: String) -> Bool {
        if let known = assetLookup.value(for: id) { return known }
        let exists = UIImage(named: id) != nil
        assetLookup.set(exists, for: id)
        return exists
    }
}

/// Overlapping cluster of food icons so category covers feel like a full dish.
/// Icons are listed back → front and stacked so rear pieces weave forward into the pile.
struct DishCoverView: View {
    let iconIDs: [String]
    var size: CGFloat = 96

    var body: some View {
        let icons = Array(iconIDs.filter { !$0.isEmpty }.prefix(3))

        ZStack {
            ForEach(Array(icons.enumerated()), id: \.offset) { index, id in
                stackedPiece(id: id, index: index, count: icons.count)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func stackedPiece(id: String, index: Int, count: Int) -> some View {
        let progress = count > 1 ? CGFloat(index) / CGFloat(count - 1) : 1
        // Back pieces sit higher/smaller; front pieces drop forward and grow.
        let piece = size * (0.52 + progress * 0.16)
        let xOffsets: [CGFloat] = [-0.22, 0.02, 0.24]
        let yOffsets: [CGFloat] = [-0.14, 0.02, 0.12]
        let rotations: [Double] = [-14, 4, 12]
        let x = size * (index < xOffsets.count ? xOffsets[index] : 0)
        let y = size * (index < yOffsets.count ? yOffsets[index] : 0)
        let angle = index < rotations.count ? rotations[index] : 0

        FoodIconView(iconID: id, size: piece)
            .shadow(color: AppTheme.nearBlack.opacity(0.12 + progress * 0.08), radius: 3 + progress * 2, y: 2)
            .rotationEffect(.degrees(angle))
            .offset(x: x, y: y)
            // Later icons paint above earlier ones, so the stack advances forward.
            .zIndex(Double(index))
    }
}
