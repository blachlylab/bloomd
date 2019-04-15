module test.testbloom;
import std.stdio;
import std.file:exists;
import bloomd.bloom;

bool[string] loadAA(string fn,ulong n){
    bool[string] map;
    if(!exists(fn)){
        throw new Exception("Missing test file");
    }
    auto f=File(fn);
    auto count=0;
    foreach(l;f.byLine){
        if(count==n){
            break;
        }
        map[l.idup]=true;
        count++;
    }
    return map;
}
auto loadBloom(string fn,ulong n,ulong ex_ins,double fpr){
    auto bf=bloomFilter(ex_ins,fpr);
    if(!exists(fn)){
        throw new Exception("Missing test file");
    }
    auto f=File(fn);
    auto count=0;
    foreach(l;f.byLine){
        if(count==n){
            break;
        }
        bf.insert(l.idup);
        count++;
    }
    return bf;
}
void checkAATrue(bool[string] map,string fn,ulong n){
    if(!exists(fn)){
        throw new Exception("Missing test file");
    }
    auto f=File(fn);
    auto count=0;
    foreach(l;f.byLine){
        if(count==n){
            break;
        }
        assert(map[l.idup]==true);
        count++;
    }
}
float checkBloomTrue(BloomFilter!0 bf,string fn,ulong n){
    float tp=0.0;
    if(!exists(fn)){
        throw new Exception("Missing test file");
    }
    auto f=File(fn);
    auto count=0;
    foreach(l;f.byLine){
        if(count==n){
            break;
        }
        if(bf.maybe_present(l.idup)==true){
            tp+=1.0;
        }
        count++;
    }
    return tp/float(n);
}
void checkAAFalse(bool[string] map,string fn,ulong n){
    if(!exists(fn)){
        throw new Exception("Missing test file");
    }
    auto f=File(fn);
    auto count=0;
    foreach(l;f.byLine){
        if(count!=n){
            count++;
            continue;
        }
        assert((l.idup in map)==null);
    }
}
float checkBloomFalse(BloomFilter!0 bf,string fn,ulong n){
    float fp=0.0;
    if(!exists(fn)){
        throw new Exception("Missing test file");
    }
    auto f=File(fn);
    auto count=0;
    foreach(l;f.byLine){
        if(count!=n){
            count++;
            continue;
        }
        if(bf.maybe_present(l.idup)==true){
            fp+=1.0;
        }
    }
    return fp;
}
unittest{
    import std.datetime.stopwatch:StopWatch,AutoStart;
    writeln("10_000 test");
    StopWatch s = StopWatch(AutoStart.no);
    s.start;
    auto m=loadAA("source/test/darkweb2017-top10000.txt",5000);
    writeln("Loaded AA:",s.peek.total!"usecs"," usecs");
    s.reset;
    s.start;
    auto b=loadBloom("source/test/darkweb2017-top10000.txt",5000,5_000,0.001);
    writeln("Loaded BF:",s.peek.total!"usecs"," usecs");
    s.reset;
    s.start;
    checkAATrue(m,"source/test/darkweb2017-top10000.txt",5000);
    writeln("Checking true AA:",s.peek.total!"usecs"," usecs");
    s.reset;
    s.start;
    auto tp=checkBloomTrue(b,"source/test/darkweb2017-top10000.txt",5000);
    writeln("Checking true BF:",s.peek.total!"usecs"," usecs, tp:",tp);
    s.reset;
    s.start;
    checkAAFalse(m,"source/test/darkweb2017-top10000.txt",5000);
    writeln("Checking false AA:",s.peek.total!"usecs"," usecs");
    s.reset;
    s.start;
    auto fp=checkBloomFalse(b,"source/test/darkweb2017-top10000.txt",5000);
    writeln("Checking false BF:",s.peek.total!"usecs"," usecs, fp:",fp);
    s.reset;
}
unittest{
    import std.datetime.stopwatch:StopWatch,AutoStart;
    writeln("10_000_000 test");
    StopWatch s = StopWatch(AutoStart.no);
    s.start;
    auto m=loadAA("source/test/10-million-password-list-top-1000000.txt",500_000);
    writeln("Loaded AA:",s.peek.total!"usecs"," usecs");
    s.reset;
    s.start;
    auto b=loadBloom("source/test/10-million-password-list-top-1000000.txt",500_000,500_000,0.001);
    writeln("Loaded BF:",s.peek.total!"usecs"," usecs");
    s.reset;
    s.start;
    checkAATrue(m,"source/test/10-million-password-list-top-1000000.txt",500_000);
    writeln("Checking true AA:",s.peek.total!"usecs"," usecs");
    s.reset;
    s.start;
    auto tp=checkBloomTrue(b,"source/test/10-million-password-list-top-1000000.txt",500_000);
    writeln("Checking true BF:",s.peek.total!"usecs"," usecs, tp:",tp);
    s.reset;
    s.start;
    checkAAFalse(m,"source/test/10-million-password-list-top-1000000.txt",500_000);
    writeln("Checking false AA:",s.peek.total!"usecs"," usecs");
    s.reset;
    s.start;
    auto fp=checkBloomFalse(b,"source/test/10-million-password-list-top-1000000.txt",500_000);
    writeln("Checking false BF:",s.peek.total!"usecs"," usecs, fp:",fp);
    s.reset;
}