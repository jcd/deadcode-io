module deadcode.io.mock;

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

class MockFileAccess : FileAccess
{
	static MockFileAccess open(string path, IOMode mode)
	{
		return null;
	}

	~this()
	{
		close();
	}

	void close()
	{
	}

	//void readAll(InputRange)(InputRange r);
	void readText(OutputRange)(OutputRange r) if (isOutputRange!(OutputRange, immutable(char)))
	{
        assert(0);
	}

	void writeText(InputRange)(InputRange r) if (isInputRange!InputRange)
	{
        assert(0);
	}

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
}


class MockFileProtocol : FileProtocol
{
	bool canHandle(URI url)
	{
		return url.schema == "mock";
	}

    bool delegate(URI url) existsCallback;
    bool exists(URI uri)
    {
        if (existsCallback is null)
        {
            if (isDir(uri))
                return true;
            
            auto e = uri.uriString.dirName in dirMockEntries;
            foreach (i; *e)
                if (i.path == uri.uriString)
                    return true;
            
            return false;
        }
        else
        {
            return existsCallback(uri);
        }
    }

    bool delegate(URI url) isDirCallback;
    bool isDir(URI uri)
    {
        if (isDirCallback is null)
        {
            return (uri.uriString in dirMockEntries) !is null;
        }
        else
        {
            return isDirCallback(uri);
        }
    }

	FileAccess open(URI url, IOMode mode)
	{
		return MockFileAccess.open(uriToPath(url), mode);
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

    FileEntry[] delegate(URI uri, string pattern, bool shallow) enumerateCallback;

    FileEntries enumerate(URI uri, string pattern = "*", bool shallow = true)
    {
        FileEntry[] e;
        if (enumerateCallback is null)
        {
            import std.algorithm.iteration : filter;
            import std.path : globMatch, baseName;

            bool f(FileEntry de) { return globMatch(baseName(de.path), pattern); }

            e = dirMockEntries.get(uri.uriString, e).filter!f.array;            
        }
        else
        {
            e = enumerateCallback(uri, pattern, shallow);
        }

        if (e.empty)
            return FileEntries(this, Variant.init, FileEntry.init); 
        else
            return FileEntries(this, Variant(e), e[0]);
    }

    FileEntry[][string] dirMockEntries;

protected:

    FileEntry getNextFileEntry(ref Variant v)
    {
        enforce(v.hasValue, "Cannot enumerate next FileEntry for empty FileEntry range");
        assert(v.peek!(FileEntry[]) != null);
        auto r = v.get!(FileEntry[]);
        r = r[1..$];
        if (r.empty())
        {
            v = Variant();
            return FileEntry();
        }
        else
        {
            v = Variant(r);
            return r[0];
        }
    }

 
}

unittest
{
	auto fp = new MockFileProtocol;

    auto entries = [ FileEntry("a/b/c"), FileEntry("a/b/d") ];
    fp.enumerateCallback = (URI uri, string pattern, bool shallow) {
        return entries;
    };

    auto r = fp.enumerate(new URI("mock://bla"));
    
    int l = 0;
    foreach (e; r)
    {
        Assert(e == entries[l]);
        l++;
    }
    Assert(l == 2);
}
