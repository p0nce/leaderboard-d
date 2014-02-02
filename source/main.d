import dhsl;
import std.stdio;
import std.string;
import std.array;
import std.conv;
import std.algorithm;

class ListScoreHandler : DynamicHttpHandler 
{
    this(Scores scores) 
    {
        super(regex("list"));
        this.scores = scores;
    }

    override HttpResponse handle(HttpRequest request, Address remote) 
    {
        HttpResponse response;
        
        enum Format
        {
            TEXT,
            JSON,
            XML,
            MSGPACK
        }

        try
        {
            Format fmt = Format.JSON;
            int N = scores.count();

            if (request.query != "")
            {
                foreach (keyvar; splitter(request.query, "&"))
                {
                    auto tok = splitter(keyvar, "=").array;
                    if (tok.length == 2)
                    {
                        if (tok[0] == "format")
                        {
                            if (tok[1] == "text")
                                fmt = Format.TEXT;
                            else if (tok[1] == "json")
                                fmt = Format.JSON;
                            else if (tok[1] == "xml")
                                fmt = Format.XML;
                            else if (tok[1] == "msgpack")
                                fmt = Format.MSGPACK;
                            else 
                                throw new Exception(format("Unknown format %s. Accepted values: 'text', 'json', 'xml', 'msgpack'."));
                        }
                        else if (tok[0] == "N")
                        {
                            N = to!int(tok[1]);
                        }
                        else 
                            throw new Exception(format("Unknown query variable %s. Accepted values are 'format' and 'N'.", tok[0]));
                    }
                    else 
                        throw new Exception(format("Coulnd't parse parameters."));
                }
            }

            final switch(fmt)
            {
                case Format.TEXT:
                    string res = "";
                    for (int i = 0; i < N; ++i)
                    {
                        res = res ~ format("%s\n%s\n", scores.data[i].name, scores.data[i].score);
                    }
                    response.content = cast(ubyte[])(res);
                    response.setHeader("Content-Type", "text/plain");
                    break;

                case Format.JSON:
                    string res = "{ \"scores\": [ \n";
                    for (int i = 0; i < N; ++i)
                    {
                        res ~= format("    { \"name\": \"%s\", \"score\": %s },\n", scores.data[i].name, scores.data[i].score);
                    }
                    res ~= "]};\n";
                    response.content = cast(ubyte[])(res);
                    response.setHeader("Content-Type", "application/json");
                    break;

                case Format.XML:
                    string res = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
                    res ~= "<scores>\n";
                    for (int i = 0; i < N; ++i)
                        res ~= format("    <entry name=\"%s\" score=\"%s\" />\n", scores.data[i].name, scores.data[i].score);
                    res ~= "</scores>\n";
                    response.content = cast(ubyte[])(res);
                    response.setHeader("Content-Type", "text/xml");
                    break;

                case Format.MSGPACK:
                    import msgpack;
                    ubyte[] res = pack(scores.data[0..N]);
                    response.content = res;
                    response.setHeader("Content-Type", "application/x-msgpack");
                    break;
            }

            response.status = 200;
            return response;
        }
        catch(Exception e)
        {
            response.status = 400;
            response.content = cast(ubyte[])(e.msg);
            return response;
        }
    }

    Scores scores;
}

class UpdateScoreHandler : DynamicHttpHandler 
{
    this(Scores scores) 
    {
        super(regex("update"));
        this.scores = scores;
    }

    override HttpResponse handle(HttpRequest request, Address remote) 
    {
        HttpResponse response;

        string query = request.query();

        bool gotName = false;
        bool gotScore = false;
        string name;
        long score;

        foreach (keyvar; splitter(query, "&"))
        {
            auto tok = splitter(keyvar, "=").array;
            if (tok.length == 2)
            {
                if (tok[0] == "name")
                {
                    name = tok[1];
                    gotName = true;
                }
                if (tok[0] == "score")
                {
                    try
                    {
                        score = to!long(tok[1]);
                        gotScore = true;
                    }
                    catch(Exception e)
                    {
                    }
                }
            }
        }

        if (gotName && gotScore)
        {
            scores.update(new Score(name, score));
            response.content = cast(ubyte[])("OK");
        }
        else
        {
            response.content = cast(ubyte[])("Error");
        }
        return response;
    }

    Scores scores;
}

class Score
{
    this(string name, long score)
    {
        this.name = name;
        this.score = score;
    }

    string name;
    long score;

    override int opCmp(Object o)
    {
        Score sco = cast(Score)o;
        return cast(int)(sco.score - score);
    }
}

class Scores
{
    this(int count)
    {
        for (int i = 0; i < count; ++i)
        {
            data ~= new Score("Anonymous", 0);
        }
    }    

    void update(Score score)
    {
        data ~= score;
        data.sort;
        data.length = data.length - 1;
    }

    // number of highscores
    int count()
    {
        return cast(int) data.length;
    }

    Score[] data;
}

void main() 
{
    auto scores = new Scores(100);
	addDynamicHandler(new UpdateScoreHandler(scores));	
    addDynamicHandler(new ListScoreHandler(scores));	

    ServerSettings settings;
    settings.port = 8080;
    settings.maxConnections = 100;
    settings.connectionTimeoutMs = 10000;
    settings.connectionQueueSize = 30;
	
	startServer(settings);
    scope(exit) stopServer();
    writeln("Server started. Press ENTER to exit.");    
    readln();
}
