# DAV - Your Friendly Script Manager

Hey there! 👋 This is DAV, a collection of shell scripts and tools I've put together to make managing my dotfiles and scripts across different machines a breeze. Think of it as your personal script butler that helps you keep your favorite tools organized and accessible wherever you go.

## What's in the Box? 🎁

- A super friendly setup script that helps you manage which scripts you want to use
- Beautiful command-line interface (thanks to `gum`!)
- Automatic linking of scripts to your local bin directory
- Works across all your machines with minimal fuss
- Smart handling of permissions and existing links

## Before You Start 🚀

You'll need a few things to get going:

- [gum](https://github.com/charmbracelet/gum) - It makes our command line look pretty! Install it first.
- A Unix-like system (macOS or Linux)
- Make sure `~/.local/bin` is in your PATH (it usually is, but just in case!)

## Getting Started 🏁

1. First, grab a copy of this repo:

```bash
git clone <repository-url>
cd dav
```

2. Run the setup script:

```bash
./setup.sh
```

The setup script will:

- Look for all `.sh` scripts in the current directory
- Show you a nice menu to pick which scripts you want to use
- Create handy shortcuts in `~/.local/bin` so you can run them from anywhere
- Take care of all the boring stuff like permissions and existing links

## How to Configure Things ⚙️

All your settings live in `~/.config/dav/settings.ini`. I chose this spot because:

- It's the standard place for config files (following XDG guidelines)
- It's separate from the scripts, so you can have different settings on different machines
- It's easy to find and backup

Here's a quick example of how scripts read from this file:

```bash
# This is how we read settings in our scripts
config_file="$HOME/.config/dav/settings.ini"
if [ -f "$config_file" ]; then
    # Read all those settings
    source <(grep = "$config_file" | sed 's/ *= */=/')
else
    echo "Oops! Can't find your settings file at $config_file"
    exit 1
fi
```

## What Scripts Are Available? 🛠️

Right now, we've got:

- `setup.sh` - The main script that helps you manage everything
- `add_link.sh` - A helper for adding new links (uses your settings.ini)

More scripts are coming soon! Feel free to suggest what you'd like to see.

## Using DAV Across Your Machines 💻

The best part? You can use this on all your machines! Here's how:

1. Clone this repo on each machine
2. Run `setup.sh` to set things up
3. Create a `~/.config/dav/settings.ini` file on each machine with your preferences
4. That's it! Your scripts will automatically use the right settings for each machine

## Want to Help? 🤝

Found a bug? Have an idea for a new feature? Want to make something better?
Feel free to open an issue or submit a pull request! This is a work in progress, and your input is super valuable.

## A Quick Note 📝

I built this because I got tired of copying scripts between machines and managing different configurations. I hope it helps you as much as it helps me! If you have any questions or run into any issues, don't hesitate to reach out.

Happy scripting! 🎉
