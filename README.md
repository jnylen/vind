# Vind

Vind is the project for [XMLTV.se](https://xmltv.se) that fetches, updates, exports data received by either email, web, ftp or manual entry.

This is an umbrella project which is a collection of multiple subapps.

**Subapplications:**

- `Augmenter` - Augments all added airings towards a set of rules in the database. It also runs them towards external databases.
- `Database` - The database for `Vind`. It runs in a seperate process inside of the **BEAM** and restarts on crashes.
- `Exporter` - All of the exporters run on each finished import.
- `FileManager` - Handles all incoming webhooks for incoming emails, FTP uploads and file system changes and sends processes these towards added channels.
- `ImageManager` - Handles all added images from channels and keeps a record of them.
- `Importer` - All importers for each format we handle. Includes XML, JSON, Excel, DOC and so on.
- `Main` - The main application where all workers, website and so on lives.
- `Shared` - Things shared between the subapps.

## Installation

Just run `sudo dpkg -i <filename>` on the downloaded `.deb` file downloaded from our repository.

## Build

You need Elixir (1.9.0+), Erlang and Rust.

Run:

```bash
./build.sh
```

## Production

- vsftpd
- wvWave (wvHtml)
- RabbitMQ

## License and authors

`Vind` is licensed under **GPLv3** and is authored by **[Joakim Nylén](https://github.com/jnylen)** which has maintained [XMLTV.se](https://xmltv.se) since 2010.
