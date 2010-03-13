#!/usr/bin/env python
"""
Home Media Streaming Server
Copyright 2009-2010 by Brian C. Lane <bcl@brianlane.com>
All Rights Reserved

"""

"""
Implement handling of byte range header
http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.35.1


Here's what Apache sends on the initial request:
HTTP/1.1 200 OK
Date: Sun, 20 Dec 2009 23:14:56 GMT
Server: Apache/2.2.13 (Fedora)
Last-Modified: Fri, 26 Sep 2008 07:51:20 GMT
ETag: "4a4001-2bc97329-457c7c8740e00"
Accept-Ranges: bytes
Content-Length: 734622505
Connection: close
Content-Type: video/mp4

Here is a range request and the response:
GET /movies/CitySlickers.mp4 HTTP/1.1
Connection: close
Host: wyatt.home
User-Agent: Roku/DVP-2.4 (012.04E00350A)
Range: bytes=517334659-

HTTP/1.1 206 Partial Content
Date: Sun, 20 Dec 2009 23:14:57 GMT
Server: Apache/2.2.13 (Fedora)
Last-Modified: Fri, 26 Sep 2008 07:51:20 GMT
ETag: "4a4001-2bc97329-457c7c8740e00"
Accept-Ranges: bytes
Content-Length: 217287846
Content-Range: bytes 517334659-734622504/734622505
Connection: close
Content-Type: video/mp4

"""

import os
import sys
import logging
import mimetypes
import datetime
import sqlite3
import traceback
from subprocess import Popen, PIPE
import operator
import cPickle

# Tornado modules
import tornado.httpserver
import tornado.ioloop
import tornado.options
import tornado.web
import tornado.httpclient
from tornado.web import StaticFileHandler

from tornado.options import define, options

define("port", default=8888, help="run on the given port", type=int)
define("database", default=os.path.join(os.getcwd(), 'library.db'), type=str)

# API Key for tmdb searches (please request your own if you alter this code
# in a substantial way). http://api.themoviedb.org
TMDB_KEY="f025da9c9066f7016a3ccdce4a9ccf3f"

# Recognized ratings strings
RATINGS = [ "G", "NC-17", "PG", "PG-13", "R", "UR", "UNRATED", "NR", 
            "TV-Y", "TV-Y7", "TV-Y7-FV", "TV-G", "TV-PG", "TV-14", "TV-MA"]

class DbSchema(object):
    """
    Database schema creation and modification
    """
    
    # Schema revisions, rev[0], etc. is a list of SQL operations to run to 
    # bring the database up to date.
    sql = ["""  create table user(id INTEGER PRIMARY KEY, username TEXT UNIQUE, password TEXT, email TEXT);
                create table source(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT UNIQUE);
                
                create table schema(version INTEGER);
                insert into schema(version) values(1);
            """,
            # Add default values
            """ insert into user(username, password) values("admin","badpassword");
        
                update schema set version=2;
            """,
            # Add media table
            """ create table media(
                    id INTEGER PRIMARY KEY,
                    path TEXT,
                    bitrate REAL,
                    length REAL,
                    media_description TEXT,
                    description TEXT
                );
            
                update schema set version=3;
            """,
            """ create table list(
                    id INTEGER PRIMARY KEY,
                    user_id INTEGER REFERENCES user(id),
                    name TEXT
                );
                
                create table list_media(
                    id INTEGER PRIMARY KEY,
                    media_id INTEGER REFERENCES media(id),
                    user_id INTEGER REFERENCES user(id),
                    list_id INTEGER REFERENCES list(id)
                );
                
                update schema set version=4;
            """,
            """ alter table user add avatar_image BLOB;
                alter table user add content_type TEXT;
                alter table user add filename TEXT;
                
                update schema set version=5;
            """,
            """ alter table media add contentType TEXT;
                alter table media add title TEXT;
                alter table media add titleSeason TEXT;
                alter table media add live INTEGER;
                alter table media add sdBifUrl TEXT;
                alter table media add hdBifUrl TEXT;
                alter table media add sdPosterUrl TEXT;
                alter table media add sdPosterImage BLOB;
                alter table media add hdPosterUrl TEXT;
                alter table media add hdPosterImage BLOB;
                alter table media add streamQuality TEXT;
                alter table media add streamFormat TEXT;
                alter table media add releaseDate TEXT;
                alter table media add rating TEXT;
                alter table media add starRating INTEGER;
                alter table media add userStarRating INTEGER;
                alter table media add shortDescriptionLine1 TEXT;
                alter table media add shortDescriptionLine2 TEXT;
                alter table media add episodeNumber INTEGER;
                alter table media add actors TEXT;
                alter table media add director TEXT;
                alter table media add categories TEXT;
                alter table media add hdBranded INTEGER;
                alter table media add isHD INTEGER;
                alter table media add textOverlayUL TEXT;
                alter table media add textOverlayUR TEXT;
                alter table media add textOverlayBody TEXT;
                alter table media add album TEXT;
                alter table media add artist TEXT;

                update schema set version=6;
            """,
            """
                alter table media add sdPosterImageType;
                alter table media add sdPosterImageFilename;
                alter table media add hdPosterImageType;
                alter table media add hdPosterImageFilename;
            
                update schema set version=7;
            """,
            """
                create table last_position(
                    id INTEGER PRIMARY KEY,
                    media_id INTEGER REFERENCES media(id),
                    user_id INTEGER REFERENCES user(id),
                    position INTEGER
                );
                
                update schema set version=8;
            """,

        ]

    def __init__(self, database):
        self.database = database
        
    def upgrade(self):
        """
        Upgrade the database to the current schema version
        """
        # Get the current schema version number
        conn = sqlite3.connect(self.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        try:
            cur.execute("select version from schema")
            version = cur.fetchone()['version']
        except:
            version = 0

        if len(self.sql) > version:
            for update in self.sql[version:]:
                cur.executescript(update)
        cur.close()
        conn.close()


class MissingSourceError(Exception):
    def __init__(self, value):
        self.value = value
    def __str__(self):
        return repr(self.value)


# From http://www.djangosnippets.org/snippets/224/
def rescale(data, width, height, force=True):
    """Rescale the given image, optionally cropping it to make sure the result image has the specified width and height."""
    import Image as pil
    from cStringIO import StringIO
    
    max_width = width
    max_height = height

    input_file = StringIO(data)
    img = pil.open(input_file)
    if not force:
        img.thumbnail((max_width, max_height), pil.ANTIALIAS)
    else:
        src_width, src_height = img.size
        src_ratio = float(src_width) / float(src_height)
        dst_width, dst_height = max_width, max_height
        dst_ratio = float(dst_width) / float(dst_height)
        
        if dst_ratio < src_ratio:
            crop_height = src_height
            crop_width = crop_height * dst_ratio
            x_offset = float(src_width - crop_width) / 2
            y_offset = 0
        else:
            crop_width = src_width
            crop_height = crop_width / dst_ratio
            x_offset = 0
            y_offset = float(src_height - crop_height) / 3
        img = img.crop((x_offset, y_offset, x_offset+int(crop_width), y_offset+int(crop_height)))
        img = img.resize((dst_width, dst_height), pil.ANTIALIAS)
        
    tmp = StringIO()
    img.save(tmp, 'JPEG')
    tmp.seek(0)
    output_data = tmp.getvalue()
    input_file.close()
    tmp.close()
    
    return output_data




def getMP4Info(filename):
    """
    Get mp4 info about the video
    """
    details = { 'type':"", 'length':0, 'bitrate':1500, 'format':""}
    cmd = "mp4info %s" % (filename)
    p = Popen( cmd, shell=True, stdout=PIPE, stderr=PIPE, stdin=PIPE, env=os.environ )
    (stdout, stderr) = p.communicate()

    # Parse the results
    for line in stdout.split('\n'):
        fields = line.split(None, 2)
        if not fields or len(fields) < 2:
            continue
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
            print stdout
            print stderr
            print traceback.format_exc()

    return details


def import_local_media(conn, cur, path):
    """
    Read a local directory and add missing files to the media database
    
    @param cur sqlite3 database cursor
    @param path absolute path to directory of media files
    
    """
    streamFormat = {    'mp4':'mp4', 'm4v':'mp4', 'mov':'mp4',
                        'wmv':'wmv',
                        'mp3':'mp3',
                        'wma':'wma'
                    }
    new_files = []
    files = os.listdir(path)
    files.sort()
    for f in files:
        if f[-3:] not in ['mp4', 'm4v', 'mov', 'wmv', 'mp3', 'wma']:
            continue
            
        # Is it in the table already?    
        try:
            cur.execute("select * from media where path=?", (os.path.join(path,f),))
            media = cur.fetchone()
        except:
            print traceback.format_exc()
            media = None
            
        if not media:
            if f[-3:] in ['mp4', 'm4v', 'mov']:
                mp4info = getMP4Info(os.path.join(path,f))
            else:
                mp4info = None

            # Insert it into the media table
            if mp4info:
                
                sql =  "insert into media(title, path, bitrate, length, media_description, streamFormat)"
                sql += " values (?,?,?,?,?,?)"
                cur.execute(sql, (os.path.basename(f)[:-4],
                                  os.path.join(path,f), mp4info['bitrate'], 
                                  mp4info['length'], 
                                  mp4info['type'] + " " + mp4info['format'],
                                  streamFormat[f[-3:]])
                            )
            else:
                cur.execute("insert into media(title, path, streamFormat) values(?,?,?)",
                            (os.path.basename(f)[:-4],
                             os.path.join(path,f),
                             streamFormat[f[-3:]])
                            )
            conn.commit()
            new_files.append((os.path.join(path,f),))

    return new_files


def import_media(sourceId):
    """
    Import new media files from a local server dircetory or from a remote
    URL. Methods supported are http, https and ftp
    
    """
    conn = sqlite3.connect(options.database)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    try:
        cur.execute("select * from source where id=?", (sourceId,))
        source = cur.fetchone()
    except:
        print traceback.format_exc()

    if not source:
        raise MissingSourceError("No source id %s" % (sourceId))
    
    if source['type'] == "local":
        # Read a local directory
        try:
            import_local_media(conn, cur, source['path'])
        except:
            # @TODO Return some kind of error report to the user
            print traceback.format_exc()
    elif source['type'] == "remote":
        # Read a remote directly listing
        try:
            import_remote_media(conn, cur, source['path'])
        except:
            # @TODO Return some kind of error report to the user
            print traceback.format_exc()

    cur.close()
    conn.close()


class BaseHandler(tornado.web.RequestHandler):
    def get_current_user(self):
        user_id = self.get_secure_cookie("user")
        if not user_id: return None

        # Check it against the database?
        
        # return self.backend.get_user_by_id(user_id)
        return user_id

    # def get_user_locale(self):
    #     if "locale" not in self.current_user.prefs:
    #         # Use the Accept-Language header
    #         return None
    #     return self.current_user.prefs["locale"]


class SearchTMDBHandler(BaseHandler):
    """
    Search themoviedb.org for matching movies
    """
    def get(self, media_id):
        pass

    @tornado.web.asynchronous
    def post(self, media_id):
        print self.request.arguments["searchTitle"]

        # Need to replace '/' with '-' in the string
        search = self.request.arguments["searchTitle"][0].replace('/','-')
        search = tornado.escape.url_escape(search)
        url = "http://api.themoviedb.org/2.1/Movie.search/en/json/%s/%s" % (TMDB_KEY, search)
        http = tornado.httpclient.AsyncHTTPClient()
        http.fetch(url, callback=self.async_callback(self.on_response, media_id))

    def on_response(self, media_id, response):
        if response.error:
            raise tornado.web.HTTPError(500)
        json = tornado.escape.json_decode(response.body)
        if len(json) > 0 and type(json[0]) != type(dict()):
            if json[0].startswith("Nothing found"):
                json = []
            else:
                print "Unknown response: " + json
                raise tornado.web.HTTPError(500)

        # Reorganize the posters so the template can get to them
        for m in json:
            # Parse the posters
            posters = {}
            for p in m["posters"]:
                size = p["image"]["size"]
                posters[size] = p["image"]
            m['posters'] = posters
            # Some don't have a cover image
            if 'cover' not in posters:
                if 'original' in posters:
                    posters['cover'] = posters['original']
                else:
                    posters['cover'] = {"url" : None} 

        name = tornado.escape.xhtml_escape(self.current_user)
        self.render(os.path.join("templates","tmdbsearch.html"), 
                    movies=json,
                    media_id=media_id,
                    name=name)

class UpdateTMDBHandler(BaseHandler):
    def get(self, media_id, tmdb_id):
        pass

    @tornado.web.asynchronous
    def post(self, media_id, tmdb_id):
        """
        Lookup the details of this movie
        """
        if self.current_user != 'admin':
            self.redirect("/media/")
            return

        url = "http://api.themoviedb.org/2.1/Movie.getInfo/en/json/%s/%s" % (TMDB_KEY, tmdb_id)
        http = tornado.httpclient.AsyncHTTPClient()
        http.fetch(url, callback=self.async_callback(self.on_response, media_id, tmdb_id))

    def on_response(self, media_id, tmdb_id, response):
        """
        Process the details from tbdb and replace associated info for this
        movie.
        """
        if response.error:
            raise tornado.web.HTTPError(500)
        json = tornado.escape.json_decode(response.body)
        if len(json) > 0 and type(json[0]) != type(dict()):
            if json[0].startswith("Nothing found"):
                json = []
            else:
                print "Unknown response: " + json
                raise tornado.web.HTTPError(500)

        # Get the current details for this movie
        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()

        cur.execute("select * from media where id=?", (media_id,))
        row = cur.fetchone()

        cur.close()
        conn.close()

        # Make a copy of the row into a dict so it can be modified
        metadata = {}
        for field in row.keys():
            metadata[field] = row[field]

        movie = json[0]
        # Parse the posters
        posters = {}
        for p in movie["posters"]:
            size = p["image"]["size"]
            if size in posters:
                posters[size].append(p["image"])
            else:
                posters[size] = [p["image"]]
        # Some don't have a cover image
        if 'cover' not in posters:
            if 'original' in posters:
                posters['cover'] = posters['original']
            else:
                posters['cover'] = {"url" : None} 
        movie['posters'] = posters
        metadata["posters"] = posters
        if "cover" in posters:
            metadata["sdPosterUrl"] = posters["cover"][0]["url"]
            metadata["hdPosterUrl"] = posters["cover"][0]["url"]

        print posters

        # @TODO
        # pull out the following:
        # name
        # rating
        # Cast "job" : "Actor"
        # Director (member of the cast with "job" : "Director"
        # overview
        # released
        # poster for cover
        # categories

        metadata["title"] = movie.get("name", metadata["title"])
        metadata["description"] = movie.get("overview", metadata["description"])
        metadata["releaseDate"] = movie.get("released", metadata["releaseDate"])
        if "rating" in movie:
            starRating = int(float(movie["rating"]) * 10)
            metadata["starRating"] = starRating;

        # Find the director and first 2 actors
        actors = []
        for person in movie["cast"]:
            if person["job"] == "Director":
                metadata["director"] = person.get("name", metadata["director"])
            if person["job"] == "Actor":
                actors.append(person["name"])
        if actors:
            metadata["actors"] = ",".join(actors)

        # Genres
        genres = []
        for genre in movie["genres"]:
            genres.append(genre["name"])
        if genres:
            metadata["categories"] = ",".join(genres)

        name = tornado.escape.xhtml_escape(self.current_user)
        self.render(os.path.join("templates","mediaedit.html"), 
                    metadata=metadata,
                    name=name,
                    movie=movie,
                    ratings=RATINGS)



class MediaPlayHandler(BaseHandler):
    def get(self, media_id):
        print self.request.headers

        # Find the source to this file
        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute("select path from media where id=?", (media_id,))
        row = cur.fetchone()
        cur.close()
        conn.close()

        # We only handle local sources right now
        filePath = row["path"]
        fileName = os.path.basename(filePath)
        if not os.path.isfile(filePath):
            raise tornado.web.HTTPError(404)

        self.set_header("Accept-Ranges", "bytes")
        
        # Get info about the file
        statinfo = os.stat(filePath)
        modified = datetime.datetime.fromtimestamp(statinfo.st_mtime)
        self.set_header("Last-Modified", modified)
        contentType, encodingType = mimetypes.guess_type(filePath)
        if contentType:
            self.set_header('Content-Type',contentType)
        else:
            pass
 

        # Is the Range header set?
        if 'Range' in self.request.headers:
            if not self.request.headers['Range'].startswith('bytes='):
                # What is the right error?
                raise tornado.web.HTTPError(500)

            (start, end) = self.request.headers['Range'][6:].split('-')
            start = int(start)
            if end:
                self.end = int(end)+1
            else:
                self.end = statinfo.st_size
            self.set_status(206)
            # Content-Range: bytes 517334659-734622504/734622505
            range = "bytes %d-%d/%d" % (start, self.end-1, statinfo.st_size)
            self.set_header("Content-Range", range)
            print "Content-Range: %s" % (range)
        else:
            # Serve up the whole file
            start = 0
            self.end = statinfo.st_size
       
        self.set_header("Content-Length", self.end-start)
        self.flush()

        print "Serving up %d to %d / %d" % (start, self.end-1, self.end-start)

        # Return the part of the file requested
        self.fp = open(filePath, 'rb')
        self.fp.seek(start)

        if self.end - start > 8192:
            blk_size = 8192
        else:
            blk_size = self.end - start
        self.request.connection.stream.write(self.fp.read(blk_size), self.finishWrite)
        self.sent = start + blk_size


    def finishWrite(self):
        """
        Keep writing the file until it is finished
        """
        if self.sent >= self.end:
            print "Finished sending %d bytes" % (self.sent)
            # Should something be done here to finish up?
            return

        if self.end - self.sent < 8192:
            blk_size = self.end - self.sent
        else:
            blk_size = 8192
        self.sent += blk_size

        self.request.connection.stream.write(self.fp.read(blk_size), self.finishWrite)        


class LoginHandler(BaseHandler):
    def get(self):
        self.render(os.path.join("templates","login.html"), name="")

    def post(self):
        # Look up the username and password in the database
        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        params = (self.get_argument("username"), self.get_argument("password"))
        cur.execute("select * from user where username=? and password=?", params)
        r = cur.fetchone()
        print r
        if r and r['username'] == self.get_argument("username"):
            self.set_secure_cookie("user", self.get_argument("username"))
        cur.close()
        conn.close()

        # This will redirect back to login if it failed
        self.redirect("/")
        return


class LogoutHandler(BaseHandler):
    def get(self):
        self.set_secure_cookie("user", "")
        self.redirect("/login")

class SourceEditHandler(BaseHandler):
    """
    Handle Editing the Media sources
    """
    @tornado.web.authenticated
    def get(self, id):
        if self.current_user != 'admin':
            self.redirect("/")

        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute("select * from source where id=?", (id,))
	row = cur.fetchone()
        cur.close()
        conn.close()

        name = tornado.escape.xhtml_escape(self.current_user)
        self.render(os.path.join("templates","sourceedit.html"), 
                    source=row,
                    name=name)
 
    @tornado.web.authenticated
    def post(self, id):
        if self.current_user != 'admin':
            self.redirect("/")
            return

        sql_set = []
        sql_args = []
        for field in self.request.arguments:
            if field[0] == "_":
                continue
            sql_set.append("%s=?" % (field))
            sql_args.append(self.get_argument(field))

        sql_args.append(int(id))
        sql = "update source set %s where id=?" % ",".join(sql_set)
        
        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute(sql, sql_args)
        conn.commit()
       
	self.redirect("/source/") 
  

class SourceHandler(BaseHandler):
    """
    Handle the Media source page and methods
    """
    @tornado.web.authenticated
    def get(self, method=None):
        if self.current_user != 'admin':
            self.redirect("/")

        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute("select * from source")
        sources = []
        for row in cur:
            sources.append([row['id'], row['name'], row['type'], row['path']])
        cur.close()
        conn.close()

        print sources
        name = tornado.escape.xhtml_escape(self.current_user)
        self.render(os.path.join("templates","sources.html"), 
                    sources=sources,
                    name=name)
        
    @tornado.web.authenticated
    def post(self, method=None):
        if self.current_user != 'admin':
            self.redirect("/")
            return

        if method == "add":
            params = (self.get_argument("name"), self.get_argument("type"), self.get_argument("path"))
            conn = sqlite3.connect(options.database)
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            try:
                cur.execute("insert into source(name, type, path) values(?,?,?)", params)

                # @TODO check for errors and report to user
                conn.commit()
            except:
                print traceback.format_exc()
            finally:
                cur.close()
                conn.close()
        self.redirect("/source/")


class MediaEditHandler(BaseHandler):
    @tornado.web.authenticated
    def get(self, media_id):
        if self.current_user != 'admin':
            self.redirect("/media/")
            return

        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()

        cur.execute("select * from media where id=?", (media_id,))
        metadata = cur.fetchone()

        cur.close()
        conn.close()
        
        name = tornado.escape.xhtml_escape(self.current_user)
        self.render(os.path.join("templates","mediaedit.html"), 
                    metadata=metadata,
                    name=name,
                    ratings=RATINGS)
        

    @tornado.web.asynchronous
    @tornado.web.authenticated
    def post(self, media_id):
        if self.current_user != 'admin':
            self.redirect("/media/")
            return
        
        # These are fields that could be blank, and not returned by the POST
        blank_fields = [ "title", "episodeNumber", "titleSeason", "shortDescriptionLine1",
                         "shortDescriptionLine2", "description", "actors", "director",
                         "categories", "starRating", "userStarRating", "sdBifUrl",
                         "hdBifUrl", "hdPosterUrl", "sdPosterUrl", "album", "artist"
                       ]

        sql_set = []
        sql_args = []
        for field in self.request.arguments:
            if field[0] == "_" or field in ["sdPosterImage", "hdPosterImage", "sdPosterUrl", "hdPosterUrl"]:
                continue
            sql_set.append("%s=?" % (field))
            sql_args.append(self.get_argument(field))
            if field in blank_fields:
                blank_fields.remove(field)
        for field in blank_fields:
            sql_set.append("%s=?" % (field))
            sql_args.append("")

        sql_args.append(int(media_id))
        sql = "update media set %s where id=?" % ",".join(sql_set)
        
        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute(sql, sql_args)
        conn.commit()
        
        # Update the images if they were included
        files = self.request.files
        if files.get("sdPosterImage", None) and files["sdPosterImage"][0]:
            sdPosterImage = files["sdPosterImage"][0]
            params = (  buffer(sdPosterImage["body"]), 
                        sdPosterImage["content_type"],
                        sdPosterImage["filename"],
                        int(media_id))
            cur.execute("update media set sdPosterImage=?,sdPosterImageType=?,sdPosterImageFilename=? where id=?", params)
            conn.commit()

        if files.get("hdPosterImage", None) and files["hdPosterImage"][0]:
            hdPosterImage = files["hdPosterImage"][0]
            params = (  buffer(hdPosterImage["body"]), 
                        hdPosterImage["content_type"],
                        hdPosterImage["filename"],
                        int(media_id))
            cur.execute("update media set hdPosterImage=?,hdPosterImageType=?,hdPosterImageFilename=? where id=?", params)
            conn.commit()
        
        cur.close()
        conn.close()

        if self.request.arguments.get("sdPosterUrl", None):
            url = self.request.arguments["sdPosterUrl"][0]
            print "Found sdPosterUrl - %s" % (url)
            http = tornado.httpclient.AsyncHTTPClient()
            http.fetch( url, 
                        callback=self.async_callback(self.on_response, media_id, url))
        else:
            self.redirect("/media/")

    def on_response(self, media_id, url, response):
        if response.error:
            raise tornado.web.HTTPError(500)

        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        params = (  buffer(response.body), 
                    response.headers["Content-Type"],
                    os.path.basename(url),
                    int(media_id))
        cur.execute("update media set sdPosterImage=?,sdPosterImageType=?,sdPosterImageFilename=? where id=?", params)
        cur.execute("update media set hdPosterImage=?,hdPosterImageType=?,hdPosterImageFilename=? where id=?", params)
        conn.commit()

        self.redirect("/media/")



class MediaHandler(BaseHandler):
    @tornado.web.authenticated
    def get(self, method=None, *args):
        if not method:
            conn = sqlite3.connect(options.database)
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()

            cur.execute("select * from user where username=?", (self.current_user,))
            row = cur.fetchone()
            print row
            if row:
                user_id = row['id']
            else:
                print "failed to find user id, DO SOMETHING HERE"
                return
          
            cur.execute("select media.*,list.name as listname from media LEFT JOIN list_media on list_media.media_id = media.id AND list_media.user_id=? LEFT JOIN list ON list.id = list_media.list_id", (user_id,))
            media = cur.fetchall()
                        
            cur.execute("select * from list where user_id=?", (user_id,))
            lists = cur.fetchall()

            cur.close()
            conn.close()

            media = sorted(media, key=operator.itemgetter("title"))
            lists = [l["name"] for l in lists]
            name = tornado.escape.xhtml_escape(self.current_user)
            self.render(os.path.join("templates","media.html"), media=media, 
                        basename=os.path.basename, lists=lists, user_id=user_id,
                        name=name)
        elif method == 'import':
            import_media(args[0])
            self.redirect("/source/")
            return

    @tornado.web.authenticated
    def post(self, method, *args):
        pass


class UserEditHandler(BaseHandler):
    @tornado.web.authenticated
    def get(self, id):
        """
        admin can update anyone, users can only edit their own
        """
        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
            
        cur.execute("select * from user where username=?", (self.current_user,))
        row = cur.fetchone()
        if row:
            user_id = int(row['id'])
        else:
            print "failed to find user id, DO SOMETHING HERE"
            return
            
        if self.current_user != 'admin' and user_id != id:
            self.redirect("/user/")
            return
    
        cur.execute("select * from user where id=?", (id,))
        row = cur.fetchone()
        if not row:
            self.redirect("/user/")
            return

        name = tornado.escape.xhtml_escape(self.current_user)
        self.render(os.path.join("templates","useredit.html"), user=row, name=name)

    @tornado.web.authenticated
    def post(self, id):
        """
        admin can update anyone, users can only edit their own
        """
        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
            
        cur.execute("select * from user where username=?", (self.current_user,))
        row = cur.fetchone()
        if row:
            user_id = int(row['id'])
        else:
            print "failed to find user id, DO SOMETHING HERE"
            return
            
        if self.current_user != 'admin' and user_id != id:
            self.redirect("/user/")
            return

        # Need a good way to handle mismatched passwords
        if self.request.arguments["password"] != self.request.arguments["password2"]:
            self.redirect("/user/edit/%s" % (id))
            return

        # These are fields that could be blank, and not returned by the POST
        blank_fields = [ "email" ]

        sql_set = []
        sql_args = []
        for field in self.request.arguments:
            if field[0] == "_" or field in ["imagefile", "password2"]:
                continue

            # If password field is blank, skip updating it
            if field == "password" and not self.get_argument(field):
                continue
            sql_set.append("%s=?" % (field))
            sql_args.append(self.get_argument(field))
            if field in blank_fields:
                blank_fields.remove(field)
        for field in blank_fields:
            sql_set.append("%s=?" % (field))
            sql_args.append("")

        sql_args.append(int(id))
        sql = "update user set %s where id=?" % ",".join(sql_set)
        
        cur.execute(sql, sql_args)
        conn.commit()
        
        # Update the image if it was included
        try:
            imagefile = self.request.files["imagefile"][0]
            params = (  sqlite3.Binary(imagefile["body"]), 
                        imagefile["content_type"],
                        imagefile["filename"],
                        int(id))
            cur.execute("update user set avatar_image=?,content_type=?,filename=? where id=?", params)
            conn.commit()
        except:
            print traceback.format_exc()
        self.redirect("/user/")


class UserHandler(BaseHandler):
    @tornado.web.authenticated
    def get(self, method=None):
        if not method:
            conn = sqlite3.connect(options.database)
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            
            cur.execute("select * from user where username=?", (self.current_user,))
            row = cur.fetchone()
            print row
            if row:
                user_id = int(row['id'])
            else:
                print "failed to find user id, DO SOMETHING HERE"
                return
            
            if self.current_user == 'admin':
                cur.execute("select * from user")
            else:
                cur.execute("select * from user where id=?", (user_id,))
            users = []
            for row in cur:
                users.append([row['id'], row['username'], row['email']])
            cur.close()
            conn.close()

            print users
            name = tornado.escape.xhtml_escape(self.current_user)
            self.render(os.path.join("templates","users.html"), users=users, name=name)

    @tornado.web.authenticated
    def post(self, method=None):
        """
        @TODO Add update user, allowing users to change their own data or admin to
              update everyones.
        """
        if method == "add":
            if self.current_user != 'admin':
                self.redirect("/")
                return

            params = (self.get_argument("username"), self.get_argument("password"),
                        self.get_argument("email", None))
            if self.get_argument("password") != self.get_argument("password2"):
                # @TODO return a warning to the user
                self.redirect("/user/")
                return
            
            conn = sqlite3.connect(options.database)
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            sql  = "insert into user(username, password, email) "
            sql += "values(?,?,?)"
            cur.execute(sql, params)
            conn.commit()
            id = cur.lastrowid

            try:
                imagefile = self.request.files["imagefile"][0]
                params = (  sqlite3.Binary(imagefile["body"]), 
                            imagefile["content_type"],
                            imagefile["filename"],
                            int(id))
                cur.execute("update user set avatar_image=?,content_type=?,filename=? where id=?", params)
                conn.commit()
            except:
                print traceback.format_exc()

            cur.close()
            conn.close()
        self.redirect("/user/")
        return


class UserLastPositionHandler(BaseHandler):
    """
    Handle the playback position for users
    This cannot be protected because the Roku doesn't login to the server, so 
    it is possible to spoof the playback positions
    """
    def get(self, user_id, media_id):
        """
        Retrieve the last position this user played for the passed media_id
        """
        print "User: %s Media %s" % (user_id, media_id)
        
    def post(self, user_id, media_id):
        """
        Save the last position this user played for the passed media_id
        """
        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        try:
            # Check to see if there is an entry for this user and media
            cur.execute("select * from last_position where user_id=? and media_id=?", (user_id, media_id))
            row = cur.fetchone()
            if not row:
                cur.execute("insert into last_position(user_id, media_id, position) "
                            "values(?,?,?)", 
                            (user_id, media_id, int(self.request.body)))
            else:
                cur.execute("update last_position set position=? where user_id=? "
                            "and media_id=?",
                            (int(self.request.body), user_id, media_id))
            conn.commit()
        except:
            print traceback.format_exc()
        finally:
            cur.close()
            conn.close()


class UserImageHandler(BaseHandler):
    def get(self, user_id):
        # Get the user's image
        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()

        try:
            cur.execute("select * from user where id=?", (int(user_id),))
            row = cur.fetchone()
        except:
            print traceback.format_exc()
        finally:
            conn.commit()
            cur.close()
            conn.close()

        if not row or not row["avatar_image"]:
            raise tornado.web.HTTPError(404)

        image = row["avatar_image"]
        from hashlib import sha1
        cksum = sha1()
        cksum.update(image)
        print cksum.hexdigest()

        image = rescale( image, 224, 158, True)
        self.set_header('Content-Type',"image/jpeg")
        self.set_header("Content-Length", len(image))
        self.write(str(image))

    @tornado.web.authenticated
    def post(self, user_id):
        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        
        try:
            imagefile = self.request.files["imagefile"][0]
            params = (  sqlite3.Binary(imagefile["body"]), 
                        imagefile["content_type"],
                        imagefile["filename"],
                        int(user_id))
            cur.execute("update user set avatar_image=?,content_type=?,filename=? where id=?", params)
        except:
            print traceback.format_exc()
        finally:
            conn.commit()
            cur.close()
            conn.close()

        self.redirect("/user/")
        return


class PosterImageHandler(BaseHandler):
    """
    Handle serving up the movie's cover art
    """
    def get(self, cover_type, media_id):
        # Get the cover's image
        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()

        try:
            cur.execute("select * from media where id=?", (int(media_id),))
            row = cur.fetchone()
        except:
            print traceback.format_exc()
        finally:
            conn.commit()
            cur.close()
            conn.close()

        if not row:
            raise tornado.web.HTTPError(404)

        if cover_type == 'sd':
            if not row["sdPosterImage"]:
                raise tornado.web.HTTPError(404)
            image = row["sdPosterImage"]
            content_type = "image/jpeg" 
            image = rescale( image, 158, 204, True )
        elif cover_type == 'hd':
            if not row["hdPosterImage"]:
                raise tornado.web.HTTPError(404)
            image = row["hdPosterImage"]
            content_type = "image/jpeg" 
            image = rescale( image, 214, 306, True)
        elif cover_type == 'thumb':
            if not row["sdPosterImage"]:
                raise tornado.web.HTTPError(404)
            image = row["sdPosterImage"]
            content_type = "image/jpeg" 
            image = rescale( image, 79, 102, True )
        else:
            if not row["sdPosterImage"]:
                raise tornado.web.HTTPError(404)

            (width, height) = cover_type.split("x")
            image = row["sdPosterImage"]
            content_type = "image/jpeg" 
            image = rescale( image, int(width), int(height), True )

        self.set_header('Content-Type',content_type)
        self.set_header("Content-Length", len(image))
        self.write(str(image))


class ListHandler(BaseHandler):
    @tornado.web.authenticated
    def get(self, method=None, *args):
        pass
        
    @tornado.web.authenticated
    def post(self, method=None, *args):
        if method == 'update':
            user_id = int(args[0])
            print self.request.arguments

            conn = sqlite3.connect(options.database)
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()

            list_names = {}
            for key in self.request.arguments:
                if not key.startswith("list-"):
                    continue

                list_name = self.request.arguments[key][0]
                if list_name == 'None':
                    continue

                media_id = int(key[5:])
                if list_name not in list_names:
                    # Check for this list name, pull its id if it exists
                    params = (list_name, user_id)
                    cur.execute("select * from list where name=? and user_id=?", params)
                    row = cur.fetchone()
                    if not row:
                        # Create it if it doesn't
                        cur.execute("insert into list(name,user_id) values(?,?)", params)
                        conn.commit()
                        list_id = cur.lastrowid
                    else:
                        list_id = row['id']
                    
                    # Add it to list_names
                    list_names[list_name] = list_id
                else:
                    list_id = list_names[list_name]

                # Check the movie to see if it has this list
                cur.execute("select * from list_media where media_id=? and user_id=?", (media_id, user_id))
                row = cur.fetchone()
                if not row:
                    cur.execute("insert into list_media(list_id,media_id,user_id) values(?,?,?)", (list_id, media_id, user_id))
                    conn.commit()
                else:
                    # Otherwise update the entry
                    if row['list_id'] != list_id:
                        cur.execute("update list_media set list_id=? where id=?", (list_id, row['id']))
                        conn.commit()
            cur.close()
            conn.close()
            self.redirect("/media/")
            return


class XMLUsersHandler(BaseHandler):
    def get(self):
        """
        Return the list of the users and their lists
        """
        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute("select * from user")
        users = []
        for row in cur:
            if row['username'] == 'admin':
                continue

            cur2 = conn.cursor()
            cur2.execute("select * from list where user_id=?", (row['id'],))
            lists = []
            for row2 in cur2:
                lists.append([row2['id'], row2['name']])
            cur2.close()
            lists = sorted(lists, key=operator.itemgetter(1))
            lists.append([-1, 'All Movies'])

            users.append([row['id'], row['username'], lists])

        users = sorted(users, key=operator.itemgetter(1))
        cur.close()
        conn.close()

        host = "%s://%s" % (self.request.protocol, self.request.host)
        self.render(os.path.join("templates","xmlusers.html"), users=users, host=host)

        
class XMLListHandler(BaseHandler):
    def get(self, user_id, list_id):
        """
        Return the User's List of media
        """
        host = "%s://%s" % (self.request.protocol, self.request.host)

        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        pos_cur = conn.cursor()

        if int(list_id) > -1:
            cur.execute("select * from media JOIN list_media on list_media.media_id = media.id AND list_media.user_id=? AND list_media.list_id=?", (int(user_id), int(list_id)))
        else:
            cur.execute("select * from media")

        media = []
        for row in cur:
#            print row
            coverImage = "%s/images/default.jpg" % (host)
            
            sdBifUrl = None
            hdBifUrl = None
            bifname = "%s-SD.bif" % (os.path.basename(row["path"]).rsplit('.', 1)[0])
#            if (os.path.isfile(bifname)):
            sdBifUrl = "%s/movies/%s" % (host,bifname)
            bifname = "%s-HD.bif" % (os.path.basename(row["path"]).rsplit('.', 1)[0])
#            if (os.path.isfile(bifname)):
            hdBifUrl = "%s/movies/%s" % (host,bifname)


            description = "%s %d kbps" % (row['media_description'], row['bitrate'])
            description += row["description"] or ""

            if row["actors"]:
                actors = row["actors"].split(",")
            else:
                actors = []

            if row["director"]:
                directors = row["director"].split(",")
            else:
                directors = []

            if row["categories"]:
                categories = row["categories"].split(",")
            else:
                categories = []

            # Get this user's last played position for this media
            lastpos = 0
            try:
                print "user_id=%s media_id=%s" % (user_id, row["id"])

                # Check to see if there is an entry for this user and media
                pos_cur.execute("select * from last_position where "
                                "user_id=? and media_id=?",
                                (int(user_id), int(row["id"])))
                pos_row = pos_cur.fetchone()
                if pos_row:
                    lastpos = int(pos_row["position"])
            except:
                pass

            metadata = {
                'contentType' : row["contentType"] or "movie",
                'title' : row["title"] or os.path.basename(row["path"])[:-4],
                'titleSeason' : row["titleSeason"],
                'description' : description[:250],
                'sdbifurl' : sdBifUrl,
                'hdbifurl' : hdBifUrl,
                'sdPosterUrl' : '%s/media/image/sd/%s' % (host, row["id"]),
                'hdPosterUrl' : '%s/media/image/hd/%s' % (host, row["id"]),
                'streams' : [{
                    'format' : row["streamFormat"],
                    'quality' : row["streamQuality"] or "SD",
                    'bitrate' : row['bitrate'],
                    'url' : "%s/media/play/%s" % (host, row["id"]),
                }],
                'length' : int(row['length']),
                'lastPos' : lastpos,
                'id' : "user_%s-list_%s-movie_%s" % (user_id, list_id, row["id"]),
                'userId' : int(user_id),
                'mediaId' : row["id"],
                'streamFormat' : row["streamFormat"],
                'releaseDate' : row["releaseDate"],
                'rating' : row["rating"],
                'starRating' : row["starRating"],
                'userStarRating' : row["userStarRating"],
                'shortDescriptionLine1' : row["shortDescriptionLine1"],
                'shortDescriptionLine2' : row["shortDescriptionLine2"],
                'episodeNumber' : row["episodeNumber"],
                'actors' : actors,
                'directors' : directors,
                'categories' : categories,
                'hdBranded' : row["hdBranded"] and "True" or "False",
                'isHD' : row["isHD"] and "True" or "False",
                'textOverlayUL' : row["textOverlayUL"],
                'textOverlayUR' : row["textOverlayUL"],
                'textOverlayBody':row["textOverlayBody"],
                'album' : row["album"],
                'artist' : row["artist"]
            }
            media.append(metadata)
        media = sorted(media, key=operator.itemgetter('title'))
        print media
        self.render(os.path.join("templates","xmllist.html"), media=media, host=host)


class MediaListHandler(BaseHandler):
    def get(self, user_id, list_id):
        """
        Return the User's List of media
        """
        host = "%s://%s" % (self.request.protocol, self.request.host)

        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()

        if int(list_id) > -1:
            cur.execute("select * from media JOIN list_media on list_media.media_id = media.id AND list_media.user_id=? AND list_media.list_id=?", (int(user_id), int(list_id)))
        else:
            cur.execute("select * from media")

        media = []
        for row in cur:
            metadata = {
                'title' : row["title"] or os.path.basename(row["path"])[:-4],
                'url' : "%s/media/play/%s" % (host, row["id"]),
            }
            media.append(metadata)
        media = sorted(media, key=operator.itemgetter('title'))
        
        cur.close()
        conn.close()
        
        name = tornado.escape.xhtml_escape(self.current_user)
        self.render(os.path.join("templates","medialist.html"), media=media, name=name)



class MainHandler(BaseHandler):
    @tornado.web.authenticated
    def get(self):
        conn = sqlite3.connect(options.database)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()

        cur.execute("select * from user where username=?", (self.current_user,))
        row = cur.fetchone()
        print row
        if row:
            user_id = row['id']
        else:
            print "failed to find user id, DO SOMETHING HERE"
            return
        
        cur.execute("select * from list where user_id=?", (user_id,))
        lists = cur.fetchall()
        lists = sorted(lists, key=operator.itemgetter("name"))
        lists.append({"id":-1, "user_id":user_id, "name":"All Movies"})
        
        cur.close()
        conn.close()
        
        name = tornado.escape.xhtml_escape(self.current_user)
        self.render(os.path.join("templates","index.html"), name=name, user_id=user_id, lists=lists)


def main():
    tornado.options.parse_command_line()

    print "Starting Home Media Server"
    print "Listening on port %s" % (options.port)
    
    # Setup the database
    if not os.path.exists(options.database):
        sqlite3.connect(options.database)
    schema = DbSchema(options.database)
    schema.upgrade()
    
    # Application setup
    settings = {
        "static_path": os.path.join(os.path.dirname(__file__), "static"),
        "cookie_secret": "480BE2C7-E684-4CFB-9BE7-E7BA55952ECB",
        "login_url": "/login",
        "xsrf_cookies": False,
    }
    
    application = tornado.web.Application([
        (r"/", MainHandler),
        (r"/login", LoginHandler),
        (r"/logout", LogoutHandler),
        (r"/source/edit/(.*)", SourceEditHandler),
        (r"/source/(.*)", SourceHandler),
        (r"/media/list/(.*)/(.*)", MediaListHandler),
        (r"/media/edit/(.*)", MediaEditHandler),
        (r"/media/play/(.*)", MediaPlayHandler),
        (r"/media/image/(.*)/(.*)", PosterImageHandler),
        (r"/media/(.*)/(.*)", MediaHandler),
        (r"/media/(.*)", MediaHandler),
        (r"/tmdb/search/(.*)", SearchTMDBHandler),
        (r"/tmdb/update/(.*)/(.*)", UpdateTMDBHandler),
        (r"/list/(.*)/(.*)", ListHandler),
        (r"/user/last/(.*)/(.*)", UserLastPositionHandler),
        (r"/user/image/(.*)", UserImageHandler),
        (r"/user/edit/(.*)", UserEditHandler),
        (r"/user/(.*)", UserHandler),
        (r"/xml/users", XMLUsersHandler),
        (r"/xml/list/(.*)/(.*)", XMLListHandler),
        (r"/css/(.*)", StaticFileHandler, dict(path=os.path.join(os.path.dirname(__file__), "static","css"))),
        (r"/js/(.*)", StaticFileHandler, dict(path=os.path.join(os.path.dirname(__file__), "static","js"))),
    ], **settings)
    http_server = tornado.httpserver.HTTPServer(application)
    http_server.listen(options.port)
    tornado.ioloop.IOLoop.instance().start()


if __name__ == "__main__":
    main()

