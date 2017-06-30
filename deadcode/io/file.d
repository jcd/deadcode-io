module deadcode.io.file;

import deadcode.core.path;


import deadcode.io.iomanager;

import std.algorithm;
import std.exception;
import std.file;
import std.range;
import std.stdio : StdFile = File;
import std.traits;
import std.variant;

import deadcode.test;
mixin registerUnittests;

class LocalFileAccess : FileAccess
{
	static LocalFileAccess open(string path, IOMode mode)
	{
		// debug std.stdio.writeln("Opening ", path);
		string modeString;

		final switch (mode)
		{
			case IOMode.read:
				modeString = "r";
				break;
			case IOMode.write:
				modeString = "w";
				if (!exists(path.dirName))
					mkdirRecurse(path.dirName);
				break;
			case IOMode.append:
				modeString = "a";
				break;
		}
		try
		{
			auto f = new LocalFileAccess;
			f._handle = StdFile(path, modeString);
			return f;
		}
		catch (Exception e)
		{
			debug 
            {
                import std.stdio;
                writeln("Cannot open", path);
			}
            return null;
		}
	}


	~this()
	{
		close();
	}

	void close()
	{
		_handle.close();
	}

	//void readAll(InputRange)(InputRange r);
	void readText(OutputRange)(OutputRange r) if (isOutputRange!(OutputRange, immutable(char)))
	{
		auto sz = cast(size_t)_handle.size;
		if (sz == 0)
			return;

		static if( __traits(compiles, r.reserve(1)))
			r.reserve(sz);

		// TODO: Get rid of temp buf for reading and read directly into input range
		char[] buf;
		buf.length = sz;
		_handle.rawRead(buf);
		r.put(buf);
	}

	void writeText(InputRange)(InputRange r) if (isInputRange!InputRange)
	{
		static if (hasSlicing!InputRange)
		{
			_handle.rawWrite(r[]);
		}
		else
		{
			foreach (elm; r)
				_handle.write(elm);
		}
		_handle.flush();
	}

	//ubyte[] readAll();

	string readText()
	{
		import std.array;
		auto res = appender!string();
		readText(res);
		return res.data;
	}

	void writeText(string output)
	{
		writeText!string(output);
	}

	private StdFile _handle;
}


class LocalFileProtocol : FileProtocol
{
	bool canHandle(URI url)
	{
		string schema = url.schema;

        // driveName is alway null on posix
        auto hasDrive = driveName(url.uriString) !is null;
		auto isWinAbsPath = hasDrive && url.uriString.length > 3 && schema.length == 1 && url.uriString[1..3] == ":/";

        return schema is null || schema == "file" || isWinAbsPath;
	}

    bool exists(URI uri)
    {
        static import std.file;
        return std.file.exists(uriToPath(uri));
    }
	
    bool isDir(URI uri)
    {
        static import std.file;
        return std.file.isDir(uriToPath(uri));
    }

	FileAccess open(URI url, IOMode mode)
	{
		return LocalFileAccess.open(uriToPath(url), mode);
	}

	string readText(URI inUrl)
	{
		return std.file.readText(uriToPath(inUrl));
	}

	static string uriToPath(URI inUrl)
	{
		import deadcode.platform.system;
		auto url = inUrl.toString();

		string origURL = url;

		if (url.startsWith("file:"))
			url = url[5..$];

		string base;
		if (url.startsWith("//"))
		{
			base = getRunningExecutablePath();
			url = url[2..$];
		}

		if (url.startsWith("/"))
		{
			// Relative to base path
			url = buildPath(base, url);
		}
		else
		{
			url = buildPath(getRunningExecutablePath, url);
		}
		return buildNormalizedPath(url);
	}

    FileEntries enumerate(URI uri, string pattern = "*", bool shallow = true)
    {
        import std.file : dirEntries;
        auto p = uriToPath(uri);
        auto e = dirEntries(p, pattern, shallow ? SpanMode.shallow : SpanMode.breadth, false); 
        if (e.empty)
            return FileEntries(this, Variant.init, FileEntry.init);
        else
            return FileEntries(this, Variant(e), createFileEntry(e.front));
    }

protected:

    alias EnumeratorType = typeof( dirEntries("","", SpanMode.shallow) );

    FileEntry getNextFileEntry(ref Variant v)
    {
        enforce(v.hasValue, "Cannot enumerate next FileEntry for empty FileEntry range");
        assert(v.peek!EnumeratorType != null);
        auto r = v.get!EnumeratorType;
        r.popFront();
        if (r.empty())
        {
            v = Variant();
            return FileEntry();
        }
        else
        {
            auto e = r.front;
            return createFileEntry(e);
        }
    }

    final FileEntry createFileEntry(DirEntry e)
    {
        return FileEntry(e.name, e.timeCreated, e.timeLastModified, e.timeLastAccessed, e.size, e.isFile, e.isDir, e.isSymlink);
    }
}

unittest
{
	auto fp = new LocalFileProtocol;

    // TODO: test on linux also
	version (Windows)
	{
	    string[] paths = [ "file:///install.ini", "file://c:/install.ini", "/install.ini" ];

	    // Convenience protocol method for reading all text in a file
	    foreach (p; paths)
	    {
		    Assert(fp.readText(new URI(p)).startsWith("[Setup]"));
	    }

	    // ditto but through allocated File
	    foreach (p; paths)
	    {
		    auto f = fp.open(new URI(p), IOMode.read);
		    Assert(f.readText().startsWith("[Setup]"));
	    }
    }
}

