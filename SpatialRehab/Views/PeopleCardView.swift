import SwiftUI

struct PeopleCardView: View {
    let person: Person

    var body: some View {
        VStack(spacing: 24) {
            Image(person.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 180, height: 180)
                .clipShape(Circle())

            Text(person.name)
                .font(.largeTitle)
                .bold()

            Text(person.relationship)
                .font(.title2)
                .foregroundStyle(.secondary)

            Divider()

            Text(person.note)
                .font(.title3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .padding(40)
    }
}
