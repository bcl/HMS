#!/usr/local/bin/python3.12
"""
Create .bif files for Roku video streaming
Copyright 2009-2013 by Brian C. Lane <bcl@brianlane.com>
All Rights Reserved


makebif.py --help for arguments

Requires ffmpeg to be in the path

NOTE: The jpg image sizes are set to the values posted by bbefilms in the Roku
      development forums. They may or may not be correct for your video aspect ratio.
      They don't look right for me when I set the video height to 480
"""
import array
from optparse import OptionParser
import os
from pathlib import Path
import shutil
import struct
from subprocess import check_output
import tempfile

# for mode 0, 1, 2, 3
videoSizes = [(240,180), (320,240), (240,136), (320,180)]

# Extension to add to the file for mode 0, 1, 2, 3
modeExtension = ['SD', 'HD', 'SD', 'HD']



def getMP4Info(filename):
    """
    Get mp4 info about the video

    mp4info is in the mp4v2 package
    """
    details = { 'type':"", 'length':0, 'bitrate':1500, 'format':"", 'size':""}
    output = check_output(["mp4info", filename], text=True)
    # Parse the results
    for line in output.split('\n'):
        fields = line.split(None, 2)
        try:
            if fields[1] == 'video':
                # parse the video info
                # MPEG-4 Simple @ L3, 5706.117 secs, 897 kbps, 712x480 @ 23.9760 24 fps
                videoFields = fields[2].split(',')
                details['type'] = videoFields[0]
                details['length'] = float(videoFields[1].split()[0])
                details['bitrate'] = float(videoFields[2].split()[0])
                details['format'] = videoFields[3]
                details['size'] = videoFields[3].split('@')[0].strip()
        except:
            pass

    return details


def extractImages( videoFile, directory, interval, mode=0, offset=0 ):
    """
    Extract images from the video at 'interval' seconds

    @param mode 0=SD 4:3 1=HD 4:3 2=SD 16:9 3=HD 16:9
    @param directory Directory to write images into
    @param interval interval to extract images at, in seconds
    @param offset offset to first image, in seconds
    """
    size = "x".join([str(i) for i in videoSizes[mode]])
    cmd = ["ffmpeg", "-i", videoFile, "-ss", "%d" % offset,
           "-r", "%0.2f" % (1.00/interval), "-s", size, "%s/%%08d.jpg" % directory]
    print(cmd)
    output = check_output(cmd, text=True)
    print(output)


def makeBIF( filename, directory, interval ):
    """
    Build a .bif file for the Roku Player Tricks Mode

    @param filename name of .bif file to create
    @param directory Directory of image files 00000001.jpg
    @param interval Time, in seconds, between the images
    """
    magic = [0x89,0x42,0x49,0x46,0x0d,0x0a,0x1a,0x0a]
    version = 0

    files = os.listdir("%s" % (directory))
    images = []
    for image in files:
        if image[-4:] == '.jpg':
            images.append(image)
    images.sort()
    images = images[1:]

    with open(filename, "wb") as f:
        array.array('B', magic).tofile(f)
        f.write(struct.pack("<I", version))
        f.write(struct.pack("<I", len(images)))
        f.write(struct.pack("<I", 1000 * interval))
        array.array('B', [0x00 for x in range(20,64)]).tofile(f)

        bifTableSize = 8 + (8 * len(images))
        imageIndex = 64 + bifTableSize
        timestamp = 0

        # Get the length of each image
        for image in images:
            statinfo = os.stat("%s/%s" % (directory, image))
            f.write(struct.pack("<I", timestamp))
            f.write(struct.pack("<I", imageIndex))

            timestamp += 1
            imageIndex += statinfo.st_size

        f.write(struct.pack("<I", 0xffffffff))
        f.write(struct.pack("<I", imageIndex))

        # Now copy the images
        for image in images:
            data = open("%s/%s" % (directory, image), "rb").read()
            f.write(data)

def main():
    """
    Extract jpg images from the video and create a .bif file
    """
    parser = OptionParser()
    parser.add_option(  "-m", "--mode", dest="mode", type='int', default=0,
                        help="(0=SD) 4:3 1=HD 4:3 2=SD 16:9 3=HD 16:9")
    parser.add_option(  "-i", "--interval", dest="interval", type='int', default=10,
                        help="Interval between images in seconds (default is 10)")
    parser.add_option(  "-o", "--offset", dest="offset", type='int', default=0,
                        help="Offset to first image in seconds (default is 7)")

    (options, args) = parser.parse_args()

    # Get the video file to operate on
    videoFile = args[0]
    print("Creating .BIF file for %s" % (videoFile))

    # This may be useful for determining the video format
    # Get info about the video file
    videoInfo = getMP4Info(videoFile)
    if videoInfo["size"]: 
        size = videoInfo["size"].split("x")
        aspectRatio = float(size[0]) / float(size[1])
        width, height = videoSizes[options.mode]
        height = int(width / aspectRatio)
        videoSizes[options.mode] = (width, height)

    tmpDirectory = tempfile.mkdtemp()

    # Extract jpg images from the video file
    extractImages( videoFile, tmpDirectory, options.interval, options.mode, options.offset )

    bifFile = "%s-%s.bif" % (os.path.basename(videoFile).rsplit('.',1)[0], modeExtension[options.mode])

    # Create the BIF file
    makeBIF( bifFile, tmpDirectory, options.interval )

    # Clean up the temporary directory
    shutil.rmtree(tmpDirectory)

    # Move it next to the source
    dest = Path(os.path.dirname(videoFile))
    if not os.path.exists(dest / bifFile):
        shutil.move(bifFile, dest)
    else:
        print(f"Not moving {bifFile}, already exists at {dest}")


if __name__ == '__main__':
    main()

