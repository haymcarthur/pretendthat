# PretendThat pitch script

Southern Utah Code Camp 2026 · Haylee McArthur · about 1:45 before the demo

## Slide 1 · Title

Hi everyone, I’m Haylee McArthur, a UX designer and a mom. This weekend I built PretendThat, a game master for real-world pretend play: an iPad app for kids 4 to 8, run by a mouse named Nutmeg.

*Cue: click to the problem slide.*

## Slide 2 · The problem

My favorite thing to hear when my children are playing is pretend that. Pretend that we are astronauts going to space. Pretend that this is a movie theater and we are the workers. 68% of parents say their child plays pretend on a typical day. But the setup is grown-up sized, so they come find me, and when I’m busy it’s easy to hand them a device. 44% of parents of 3 to 5 year olds use device games to keep kids busy, and kids 8 and under average 2.5 hours of screen time a day.

*Cue: pause on the stats for a beat, then click.*

## Slide 3 · Meet Nutmeg

I didn’t want to take away the convenience of the iPad, but I wanted it to get them using their imagination and the things around them. So I gave them a stage manager: Nutmeg. Kids pick a game by talking to her, hunt for props, and color a custom printable kit, then she guides the show and steps back so the play happens off the screen. And she never asks for kids’ names, and nothing is stored.

*Cue: point at the four cards left to right as you say each step, then click.*

## Slide 4 · Under the hood

PretendThat is a native iPad app built in SwiftUI. Nutmeg talks live through OpenAI’s Realtime voice, Claude writes each kit and the scenes, and the coloring pages are drawn by OpenAI’s GPT Image model. And it’s backed by 202 automated tests.

*Cue: click to the demo slide.*

## Slide 5 · Live demo

Parents pay for printable kits and kids’ voice apps, but I couldn’t find anything that builds a game around what’s in your house and hands the play back to the kids. Let’s play pretend!

*Cue: switch to the iPad.*

### Demo order

1. Open the app and say hi to Nutmeg (hold the mic button to talk).
2. **Game:** say a game and theme out loud (for example "a movie theater" or "a pancake restaurant on the moon"), then tell her how many kids are playing.
3. **Props:** show the prop hunt, find one prop, then tap "Don't have it" on another to hear "we'll just pretend that…".
4. **Print:** show the kit being drawn page by page while Nutmeg writes on her clipboard, then the finished kit and the one-tap AirPrint button.
5. **Play:** show the scene checklist: check a step, then tap the Repeat button in the bottom bar to hear the steps read aloud.
6. Stop talking and let Nutmeg get sleepy and nap, to show she steps back.

*Backup: bring a phone hotspot. Nutmeg's voice needs internet; if the image drawing fails, the kit falls back to built-in pages.*
