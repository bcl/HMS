#!/usr/bin/env python
# encoding: utf-8
"""
staticvideo.py

Created by Brian Lane on 2009-12-20.
Copyright (c) 2009 Nexus Computing. All rights reserved.


Categories example XML:

<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<categories>
  <banner_ad sd_img="http://rokudev.roku.com/rokudev/examples/videoplayer/images/missing.png" hd_img="http://rokudev.roku.com/rokudev/examples/videoplayer/images/missing.png"/>
  
<category title="Technology" description="TED Talks on Technology" sd_img="http://rokudev.roku.com/rokudev/examples/videoplayer/images/TED_Technology.png" hd_img="http://rokudev.roku.com/rokudev/examples/videoplayer/images/TED_Technology.png">
	<categoryLeaf title="The Mind" description="" feed="http://rokudev.roku.com/rokudev/examples/videoplayer/xml/themind.xml"/>
	<categoryLeaf title="Global Issues" description="" feed="http://rokudev.roku.com/rokudev/examples/videoplayer/xml/globalissues.xml" />
</category>

</categories>

Example Feed XML:

<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<feed>
	<!-- resultLength indicates the total number of results for this feed -->
	<resultLength>4</resultLength>
	<!-- endIndix  indicates the number of results for this *paged* section of the feed -->
	<endIndex>4</endIndex>
	<item sdImg="http://rokudev.roku.com/rokudev/examples/videoplayer/images/JeffHan.jpg" hdImg="http://rokudev.roku.com/rokudev/examples/videoplayer/images/JeffHan.jpg">
		<title>Jeff Han demos his breakthrough touchscreen</title>
		<contentId>10061</contentId>
		<contentType>Talk</contentType>
		<contentQuality>SD</contentQuality>
		<media>
			<streamFormat>mp4</streamFormat>
			<streamQuality>SD</streamQuality>
			<streamBitrate>1500</streamBitrate>
			<streamUrl>http://video.ted.com/talks/podcast/JeffHan_2006_480.mp4</streamUrl>
		</media>
		<synopsis>After years of research on touch-driven computer displays, Jeff Han has created a simple, multi-touch, multi-user screen interface that just might herald the end of the point-and-click era.</synopsis>
		<genres>Design</genres>
		<runtime>531</runtime>
	</item>	
</feed>



1st pass:
 * create a sqlite database someplace
 * --add command to add a new movie
 * generate static XML


"""

import sys
import os
import sqlite3
from optparse import OptionParser
from subprocess import Popen, PIPE

BASE_URL="http://wyatt.home/movies/"

def setup_config(path):
    """
    Create the configuration directory
    Setup the SQLite database
    Ask for the Amazon AWS credentials


    """
    pass
#    os.mkdir(path, 0700)
#    conn = sqlite3.connect(os.path.join(path,"homevideo.db"))
#    c = conn.cursor()
#    c.execute('''create table stocks
#                (date text, trans text, symbol text,
#                qty real, price real)''')
#
#    conn.commit()
#    c.close()


def getMP4Info(filename):
    """
    Get mp4 info about the video
    """
    details = { 'type':"", 'length':0, 'bitrate':1500, 'format':""}
    cmd = "mp4info %s" % (filename)
    p = Popen( cmd, shell=True, stdout=PIPE, stderr=PIPE, stdin=PIPE )
    (stdout, stderr) = p.communicate()

    # Parse the results
    for line in stdout.split('\n'):
        fields = line.split(None, 2)
        try:
            if fields[1] == 'video':
                # parse the video info
                # MPEG-4 Simple @ L3, 5706.117 secs, 897 kbps, 712x480 @ 23.976024 fps
                videoFields = fields[2].split(',')
                details['type'] = videoFields[0]
                details['length'] = float(videoFields[1].split()[0])
                details['bitrate'] = float(videoFields[2].split()[0])
                details['format'] = videoFields[3]
        except:
            pass

    return details


def makeFeedNode(filename):
    """
    Create a simple XML node using the filename
    """
    details = getMP4Info(filename)

    coverImage = "default.jpg"
    title = filename[:-4]
    contentID = 100
    contentType = "Movie"
    contentQuality = "SD"
    streamFormat = "mp4"
    streamQuality = "SD"
    streamBitrate = details['bitrate']
    runtime = int(details['length'])
    genres = ["Unknown"]
    sdBifUrl = None
    hdBifUrl = None
    synopsis = "%s %s %d kbps" % (details['type'], details['format'], details['bitrate'])
 
    bifname = "%s-SD.bif" % (filename.rsplit('.', 1)[0])
    if (os.path.isfile(bifname)):
        sdBifUrl = bifname
    bifname = "%s-HD.bif" % (filename.rsplit('.', 1)[0])
    if (os.path.isfile(bifname)):
        hdBifUrl = bifname
  
    xml  = '<item sdImg="%simages/%s" hdImg="%simages/%s">\n' % (BASE_URL, coverImage, BASE_URL, coverImage)
    xml += '    <title>%s</title>\n' % (title)
    xml += '    <contentId>%d</contentId>\n' % (contentID)
    xml += '    <contentType>%s</contentType>\n' % (contentType)
    xml += '    <contentQuality>%s</contentQuality>\n' % (contentQuality)
    xml += '    <media>\n'
    xml += '        <streamFormat>%s</streamFormat>\n' % (streamFormat)
    xml += '        <streamQuality>%s</streamQuality>\n' % (streamQuality)
    xml += '        <streamBitrate>%d</streamBitrate>\n' % (streamBitrate)
    xml += '        <streamUrl>%s%s</streamUrl>\n' % (BASE_URL, filename)
    xml += '    </media>\n'
    
    if sdBifUrl:
        xml += '    <sdBifUrl>%s%s</sdBifUrl>\n' % (BASE_URL, sdBifUrl)
    if hdBifUrl:
        xml += '    <hdBifUrl>%s%s</hdBifUrl>\n' % (BASE_URL, hdBifUrl)

    xml += '    <synopsis>%s</synopsis>\n' % (synopsis)
    xml += '    <genres>%s</genres>\n' % (','.join(genres))
    xml += '    <runtime>%d</runtime>\n' % (runtime)
    xml += '</item>\n'
 
    return xml


def makeDirXml():
    """
    Make an XML file of the video in the current directory

    mp4, m4v extensions
    """
    nodes = []
    files = os.listdir(".")
    files.sort()
    for f in files:
        if f[-3:] in ['mp4', 'm4v']:
            nodes.append( makeFeedNode(f) )

    feedXML =  '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    feedXML += '<feed>\n'
    feedXML += '<resultLength>%d</resultLength>\n' % (len(nodes))
    feedXML += '<endIndex>%d</endIndex>\n' % (len(nodes))
    for n in nodes:
        feedXML += n
    feedXML += '</feed>\n'

    print feedXML



def main():
    """
    Setup environment if it is missing

    Parse command line options
    """
    if os.getuid() == 0:
        sys.stderr.write("Please do not run as root, use an unprivledged user")
        sys.exit(-1)
            

    parser = OptionParser(version="%prog $Id$")
    parser.add_option("-a", "--add", dest="add",
                        help="add a movie")
    parser.add_option("-d", "--directory", dest="dir", 
                        default="~/.homevideo",
                        help="Directory for config and sqlite db")

    (options, args) = parser.parse_args()

    if not os.path.isdir(options.dir):
#        print("Creating config directory: %s" % (options.dir))
        setup_config(options.dir)

    if options.add:
        print("Add a movie: %s" % (options.add))


    makeDirXml()



if __name__ == '__main__':
	main()

