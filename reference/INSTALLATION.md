# Installation

## Quick Start

1. `gem install mailcatcher-ng`
2. `mailcatcher`
3. Go to http://127.0.0.1:1080/
4. Send mail through smtp://127.0.0.1:1025

## Requirements

### Ruby

Make sure you have [Ruby installed](https://www.ruby-lang.org/en/documentation/installation/):

```bash
ruby -v
gem environment
```

You might need to install build tools for some of the gem dependencies:
- **Debian/Ubuntu**: `apt install build-essential`
- **macOS**: `xcode-select --install`

## Installation Methods

### Using gem (Recommended)

```bash
gem install mailcatcher-ng
```

### From Source

To compile MailCatcher as a gem from source:

1. Clone the repository:

```bash
git clone https://github.com/spaquet/mailcatcher.git
cd mailcatcher
```

2. Install dependencies:

```bash
bundle install
```

3. Compile assets and build the gem:

```bash
bundle exec rake package
```

This will create a `.gem` file in the project directory. The build process:

* Compiles JavaScript assets using Sprockets and Uglifier
* Creates a gem package with all required files

4. Install the compiled gem locally:

```bash
gem install mailcatcher-VERSION.gem
```

## Upgrading

Upgrading works the same as installation:

```bash
gem install mailcatcher-ng
```

## Special Setup Scenarios

### Bundler

Please don't put mailcatcher into your Gemfile. It will conflict with your application's gems at some point.

Instead, add a note in your README stating you use mailcatcher, and instruct users to run:

```bash
gem install mailcatcher-ng
mailcatcher
```

### RVM

Under RVM your mailcatcher command may only be available under the ruby you install mailcatcher into. To prevent this and to prevent gem conflicts, install mailcatcher into a dedicated gemset with a wrapper script:

```bash
rvm default@mailcatcher --create do gem install mailcatcher-ng
ln -s "$(rvm default@mailcatcher do rvm wrapper show mailcatcher)" "$rvm_bin_path/"
```

### Docker

The official MailCatcher Docker image is available [on Docker Hub](https://hub.docker.com/r/stpaquet/alpinemailcatcher):

```bash
docker run -d -p 1080:1080 -p 1025:1025 stpaquet/alpinemailcatcher
```

Example output:

```
Unable to find image 'stpaquet/alpinemailcatcher:latest' locally
latest: Pulling from stpaquet/alpinemailcatcher
4abcf2090661: Pull complete
9f403268fa96: Pull complete
6c9f5f5b4c6d: Pull complete
Digest: sha256:a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0
Status: Downloaded newer image for stpaquet/alpinemailcatcher:latest
Starting MailCatcher NG v1.0.0
==> smtp://0.0.0.0:1025
==> http://0.0.0.0:1080
```

Port mapping may vary based on your Docker configuration. For example, you may need to use `http://127.0.0.1:1080` or `smtp://127.0.0.1:1025` instead of the listed address. The image is Alpine Linux based for minimal size and quick startup.
