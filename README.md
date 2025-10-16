MIME is a swift package that parses generic MIME formatted multipart data.

Example data:

```txt
From: Nathan Borror <zV6nZFTyrypSgXo1mxC02yg6PKeXv8gWpKWa1/AzAPw=>
Date: Wed, 15 Oct 2025 18:42:00 -0700
MIME-Version: 1.0
Content-Type: multipart/bookmark; boundary="bookmark"

--bookmark
Content-Type: text/book-info
Title: Why Greatness Cannot Be Planned
Subtitle: The Myth of the Objective
Authors: Kenneth O. Stanley, Joel Lehman
ISBN-13: 978-3319155234
Published: 18 May 2015
Language: en
Pages: 135

--bookmark
Content-Type: text/quote; charset="utf-8"
Page: 10
Date: Thu, 29 May 2025 16:20:00 -0700

“Sometimes the best way to achieve something great is to stop trying to achieve a particular great thing. In other words, greatness is possible if you are willing to stop demanding what that greatness should be. While it seems like discussing objectives leads to one paradox after another, this idea really should make sense. Aren’t the greatest moments and epiphanies in life so often unexpected and unplanned? Serendipity can play an outsized role in life. There’s a reason for this pattern. Even though serendipity is often portrayed as a happy accident, maybe it’s not always so accidental after all. In fact, as we’ll show, there’s a lot we can do to attract serendipity, aside from simply betting on random luck.”

--bookmark
Content-Type: text/note; charset="utf-8"
Page: 10
Date: Thu, 29 May 2025 16:20:00 -0700

This book is turning out to be very cathartic. It’s also preaching to the choir so I probably won’t finish it!

--bookmark
Content-Type: text/progress
Page: 65
Date: Wed, 13 Oct 2025 18:42:00 -0700

--bookmark
Content-Type: text/review; charset="utf-8"
Date: Wed, 15 Oct 2025 18:42:00 -0700
Rating: 4.5
Spoilers: false

I enoyed this book!
--bookmark--
```
