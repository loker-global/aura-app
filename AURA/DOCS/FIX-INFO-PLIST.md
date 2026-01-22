# 🔧 Quick Fix for Microphone Permission

The app crashed because the Info.plist needs to be properly added to the Xcode project.

## The Issue
- Modern Xcode projects auto-generate Info.plist
- We need to tell Xcode to use our custom Info.plist with the microphone permission

## ✅ Quick Fix (Do This Now)

**I've opened Xcode for you.** Follow these steps:

### Steps in Xcode:

1. **In the left sidebar**, find and **select `Info.plist`** file (in the `aura` folder)

2. **If you don't see Info.plist:**
   - Right-click on `aura` folder
   - Choose **Add Files to "aura"...**
   - Select `Info.plist` from `aura/aura/` directory
   - Click **Add**

3. **Configure the target:**
   - Select the **`aura` project** in the left sidebar (top blue icon)
   - Select the **`aura` target** in the middle
   - Go to **Build Settings** tab
   - Search for **"Info.plist"**
   - Set **"Info.plist File"** to: `aura/Info.plist`

4. **Clean and rebuild:**
   - Menu: **Product → Clean Build Folder** (Cmd+Shift+K)
   - Menu: **Product → Build** (Cmd+B)
   - Menu: **Product → Run** (Cmd+R)

## Alternative: Command Line Fix

If you prefer command line, run this:

```bash
cd /Users/lxps/Documents/GitHub/aura-app/AURA/aura

# The Info.plist file already exists with the correct content
# Just need to rebuild after adding it to the project

# Open Xcode and add it manually (easiest)
open aura.xcodeproj
```

## What the Info.plist Contains

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSMicrophoneUsageDescription</key>
	<string>AURA needs microphone access to capture voice and visualize it in real time.</string>
</dict>
</plist>
```

## After the Fix

Once you've added the Info.plist to the project:
1. Clean (Cmd+Shift+K)
2. Build (Cmd+B)
3. Run (Cmd+R)
4. Grant microphone permission when prompted
5. Start speaking and watch the orb respond!

---

**Sorry for the project file corruption!** This is now the cleanest path forward.

The Info.plist file is created and ready at:
`/Users/lxps/Documents/GitHub/aura-app/AURA/aura/aura/Info.plist`

Just add it to the project in Xcode and you're good to go! 🚀
