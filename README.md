# Rick & Morty API App

A small Flutter application that fetches character data from the **Rick and Morty API** and displays it in a clean and simple interface.  
The project demonstrates working with HTTP requests, JSON serialization, UI building, and screen navigation.

---

## 🧩 API Usage

The app interacts with the open REST API: https://rickandmortyapi.com

Main steps of API interaction:

- Performing HTTP GET requests.
- Deserializing JSON into a `Character` model.
- Displaying the list of characters in the UI.
- Handling states: **loading**, **success**, **error**.
- Passing model data to the details screen.

---

## 🧭 Navigation

Navigation is implemented using Flutter’s standard navigation tools:

- **HomeScreen** — displays the list of characters.
- **CharacterDetailsScreen** — shows detailed information about a selected character.

Screen transitions are handled with:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => CharacterDetails(character: character),
  ),
);
