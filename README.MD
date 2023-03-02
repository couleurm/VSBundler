Instead of having to do these steps each time in CI, I wanted to separate the downloading and unzipping part into a separate step

This was made by a powershell wizard to run on a remote server, if you are a human consider checking out [VapourSynth Portable Maker](https://github.com/SaltyChiang/VapourSynth-Portable-Maker)

#### Q: Why is the "stripped version" barely smaller?

A: The zipped size is almost the same, what differs is the size unzipped, which is twice as small
* DLLs and .pyd have been compressed with UPX -9
* Various utilities and libs that Smoothie do not use have been removed, see Stripping section in [smCi.ps1](https://github.com/couleurm/VSBundler/blob/main/smCi.ps1)
