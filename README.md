SybDeRipper
===========

# about

SybDeRipper is a bash script to backup (Video) DVDs via gddrescue. Once backed up it offers to encode the video tracks on the disk and suggests the longest track (playback time). It is a fiance-friendly-frontend for ddrescue and mencoder.

# dependencies

* awk
* bash
* ddrescue
* dialog
* lsdvd
* mencoder
* grep
* sed
and some menocder profiles I have in use.

# install

```
git clone git@github.com:nerdyness/SybDeRipper.git
cd SybDeRipper
./ripper.sh
```

# license

Copyright © 2013 Stefan Krist

SybDeRipper is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

SybDeRipper is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with SybDeRipper.  If not, see <http://www.gnu.org/licenses/>.
