import SwiftUI

struct MyPeopleView: View {
    let people = [
        Person(
            name: "Brian",
            relationship: "My Son",
            imageName: "brian",
            note: "Brian usually buys me Min Jiang Kueh on Saturdays."
        ),
        Person(
            name: "Aditya",
            relationship: "My Son",
            imageName: "aditya",
            note: "Aditya lives in outer space, visits me in the evenings."
        ),
        Person(
            name: "Emma",
            relationship: "My Granddaughter",
            imageName: "emma",
            note: "Emma likes playing Mahjong with me."
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 220))
                    ],
                    spacing: 24
                ) {
                    ForEach(people) { person in
                        NavigationLink {
                            PeopleCardView(person: person)
                        } label: {
                            VStack(spacing: 16) {
                                Image(person.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 140, height: 140)
                                    .clipShape(Circle())

                                Text(person.name)
                                    .font(.title2)
                                    .bold()

                                Text(person.relationship)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .glassBackgroundEffect()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(40)
            }
            .navigationTitle("My People")
        }
    }
}
