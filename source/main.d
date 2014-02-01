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
        response.content = cast(ubyte[])(scores.toString());
        return response;
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

    Score[] data;

    override string toString()
    {
        string res = "";
        for (size_t i = 0; i < data.length; ++i)
        {
            res = res ~ format("%s\n%s\n", data[i].name, data[i].score);
        }
        return res;
    }

    void update(Score score)
    {
        data ~= score;
        data.sort;
        data.length = data.length - 1;
    }
}

void main() 
{
    auto scores = new Scores(20);
	addDynamicHandler(new UpdateScoreHandler(scores));	
    addDynamicHandler(new ListScoreHandler(scores));	

    ServerSettings settings;
    settings.port = 8080;
	
	startServer(settings);
    scope(exit) stopServer();
    writeln("Server started. Press ENTER to exit.");    
    readln();
}
