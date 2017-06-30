module deadcode.io.iomanager;

import std.datetime;
import std.exception;
import std.variant;

public import deadcode.core.uri;


/** IO specific exception
*/
class IOException : Exception
{
	this(string s, string file = __FILE__, int line = __LINE__) {
        super(s, file, line);
    }
}

interface FileAccess
{
	void close();

	//void readAll(InputRange)(InputRange r);
	void readText(OutputRange)(OutputRange r);
	void writeText(InputRange)(InputRange r);

	//ubyte[] readAll();
	string readText();
	void writeText(string output);
}

enum IOMode
{
	read,
	write,
	append
}

struct FileEntry
{
    string path;
    SysTime createdTime;
    SysTime lastModifiedTime;
    SysTime lastAccessedTime;
    ulong size;
    bool isFile;
    bool isDir;
    bool isLink;
}

struct FileEntries
{
    private FileProtocol _protocol;
    private Variant _data;
    private FileEntry _front;

    this(FileProtocol p, Variant d, FileEntry e)
    {
        _protocol = p;
        _data = d;
        _front = e;
    }
    
    @property FileEntry front() 
    {
        return _front;
    }

    void popFront()
    {
        _front = _protocol.getNextFileEntry(_data);
    }
    
    bool empty()
    {
        return ! _data.hasValue;
    }
}

interface FileProtocol
{
	bool canHandle(URI uri);
	bool exists(URI uri);
	bool isDir(URI uri);
    FileAccess open(URI uri, IOMode mode);
    FileEntries enumerate(URI uri, string pattern = "*", bool shallow = true);

protected:
    FileEntry getNextFileEntry(ref Variant v);
}

//class ScanProtocol : IOProtocol
//{
//    bool canHandle(URI uri)
//    {
//        import std.algorithm;
//        return uri.schema == "scan";
//    }
//
//    IO open(URI uri)
//    {
//        return null;
//    }
//}

class FileManager
{
	FileAccess open(URI uri, IOMode mode)
	{
		auto iop = getProtocol(uri);
		return iop.open(uri, mode);
	}

	FileProtocol getProtocol(string uri)
    {
        return getProtocol(new URI(uri));
    }
    
    FileProtocol getProtocol(URI uri)
	{
		auto iop = getProtocolImpl(uri);
		if (iop is null)
        {
        	import std.string : format;
        	throw new IOException(format("No handler for URI '%s'", uri));
        }
		return iop;
	}

	private FileProtocol getProtocolImpl(URI uri)
	{
		FileProtocol io = null;
		foreach (k,v; _factories)
		{
			if (v.canHandle(uri))
				return v;
		}
		return null;
	}

	void add(FileProtocol p)
	{
		_factories ~= p;
	}

	FileProtocol[] _factories;
}
