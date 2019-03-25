module bloom;

import std.bitmanip:BitArray;
import std.math:log,pow,ceil;
import std.conv:to;
import murmurhash;
//! A simple bloom filter implementation.
//! A bloom filter is a compact probabilistic data structure that
//! affords storage savings in favor of a chance of false positives
//! when querying the structure. More info can be found at
//! http://en.wikipedia.org/wiki/Bloom_filter.
//! By: Brian A. Madden - brian.a.madden@gmail.com
//  design stolen from https://github.com/jonalmeida/bloom-filter
struct BloomFilter{
    BitArray arr;
    uint array_size;
    uint num_hashes;
    // Figure out necessary size of bit_vec (m bits)
        // m = -(n ln(p)) / ln(2)^2

        // Figure out necessary number of hash functions (k)
        // k = (m / n) ln(2)

        // n = expected_inserts
        // p = fpr

        // Verify that fpr != 0, this will cause errors
    this(ulong expected_inserts,double fpr){
        assert(fpr!=0.0);
        array_size=((-1.0 * (expected_inserts.to!double) * fpr.log) / double(2.0).log.pow(2.0)).ceil().to!uint;
        bool[] t=new bool[array_size];
        arr=BitArray(t);
        num_hashes=(((array_size.to!double) / (expected_inserts.to!double)) * double(2.0).log()).ceil().to!uint;
        num_hashes=num_hashes+num_hashes%8;
    }
    void insert(string value){
        static if(__traits(targetHasFeature, "sse2")){
            static if(__traits(targetHasFeature, "avx2")){
                for(auto i=0;i<num_hashes-8;i+=8){
                    auto res=MurmurHash3_32_8seed(i,i+1,i+2,i+3,i+4,i+5,i+6,i+7).hash(value);
                    __vector(ulong[8]) r;
                    r[0]=res[0];r[1]=res[1];r[2]=res[2];r[3]=res[3];
                    r[4]=res[4];r[5]=res[5];r[6]=res[6];r[7]=res[7];
                    r *=cast(ulong) array_size;
                    __vector(ulong[8]) s=[32,32,32,32,32,32,32,32];
                    r >>=s;
                    arr[r[0]]=true;
                    arr[r[1]]=true;
                    arr[r[2]]=true;
                    arr[r[3]]=true;
                    arr[r[4]]=true;
                    arr[r[5]]=true;
                    arr[r[6]]=true;
                    arr[r[7]]=true;
                }
            }else{
                for(auto i=0;i<num_hashes-4;i+=4){
                    auto res=MurmurHash3_32_4seed(i,i+1,i+2,i+3).hash(value);
                    __vector(ulong[4]) r;
                    r[0]=res[0];r[1]=res[1];r[2]=res[2];r[3]=res[3];
                    r *=cast(ulong) array_size;
                    __vector(ulong[4]) s=[32,32,32,32];
                    r >>=s;
                    arr[r[0]]=true;
                    arr[r[1]]=true;
                    arr[r[2]]=true;
                    arr[r[3]]=true;
                }
            }
        }else{
            for(auto i=0;i<num_hashes;i++){
                auto res=MurmurHash3_32(i).hash(value);
                res=cast(uint)((cast(ulong)  res* cast(ulong) array_size) >> 32);
                arr[res]=true;
            }
        }
    }
    bool maybe_present(string value){
        static if(__traits(targetHasFeature, "sse2")){
            static if(__traits(targetHasFeature, "avx2")){
                for(auto i=0;i<num_hashes-8;i+=8){
                    auto res=MurmurHash3_32_8seed(i,i+1,i+2,i+3,i+4,i+5,i+6,i+7).hash(value);
                    __vector(ulong[8]) r;
                    r[0]=res[0];r[1]=res[1];r[2]=res[2];r[3]=res[3];
                    r[4]=res[4];r[5]=res[5];r[6]=res[6];r[7]=res[7];
                    r *=cast(ulong) array_size;
                    __vector(ulong[8]) s=[32,32,32,32,32,32,32,32];
                    r >>=s;
                    if((arr[r[0]] & arr[r[1]] & arr[r[2]] & arr[r[3]] &
                        arr[r[4]] & arr[r[5]] & arr[r[6]] & arr[r[7]])^1){
                        return false;
                    }
                }
            }else{
                for(auto i=0;i<num_hashes-4;i+=4){
                    auto res=MurmurHash3_32_4seed(i,i+1,i+2,i+3).hash(value);
                    __vector(ulong[4]) r;
                    r[0]=res[0];r[1]=res[1];r[2]=res[2];r[3]=res[3];
                    r *=cast(ulong) array_size;
                    __vector(ulong[4]) s=[32,32,32,32];
                    r >>=s;
                    if((arr[r[0]] & arr[r[1]] & arr[r[2]] & arr[r[3]])^1){
                        return false;
                    }
                }
            }
            return true;
        }else{
            for(auto i=0;i<num_hashes;i++){
                auto res=MurmurHash3_32(i).hash(value);
                res=cast(uint)((cast(ulong)  res* cast(ulong) array_size) >> 32);
                if(arr[res]^1){
                    return false;
                }
            }
            return true;
        }
    }
}
struct BloomFilterK(ulong k){
    BitArray arr;
    uint array_size;
    uint num_hashes;
    // Figure out necessary size of bit_vec (m bits)
        // m = -(n ln(p)) / ln(2)^2

        // Figure out necessary number of hash functions (k)
        // k = (m / n) ln(2)

        // n = expected_inserts
        // p = fpr

        // Verify that fpr != 0, this will cause errors
    this(ulong expected_inserts,double fpr){
        array_size=((-1.0 * (expected_inserts.to!double) * fpr.log) / double(2.0).log.pow(2.0)).ceil().to!uint;
        bool[] t=new bool[array_size];
        arr=BitArray(t);
        num_hashes=(((array_size.to!double) / (expected_inserts.to!double)) * double(2.0).log()).ceil().to!uint;
        num_hashes=num_hashes+num_hashes%8;
    }
    void insert(string value){
        static if(__traits(targetHasFeature, "sse2")){
            static if(__traits(targetHasFeature, "avx2")){
                for(auto i=0;i<num_hashes-8;i+=8){
                    auto res=murmurhash3_32_8seed!k(value,i,i+1,i+2,i+3,i+4,i+5,i+6,i+7);
                    __vector(ulong[8]) r;
                    r[0]=res[0];r[1]=res[1];r[2]=res[2];r[3]=res[3];
                    r[4]=res[4];r[5]=res[5];r[6]=res[6];r[7]=res[7];
                    r *=cast(ulong) array_size;
                    __vector(ulong[8]) s=[32,32,32,32,32,32,32,32];
                    r >>=s;
                    arr[r[0]]=true;
                    arr[r[1]]=true;
                    arr[r[2]]=true;
                    arr[r[3]]=true;
                    arr[r[4]]=true;
                    arr[r[5]]=true;
                    arr[r[6]]=true;
                    arr[r[7]]=true;
                }
            }else{
                for(auto i=0;i<num_hashes-4;i+=4){
                    auto res=murmurhash3_32_4seed!k(value,i,i+1,i+2,i+3);
                    __vector(ulong[4]) r;
                    r[0]=res[0];r[1]=res[1];r[2]=res[2];r[3]=res[3];
                    r *=cast(ulong) array_size;
                    __vector(ulong[4]) s=[32,32,32,32];
                    r >>=s;
                    arr[r[0]]=true;
                    arr[r[1]]=true;
                    arr[r[2]]=true;
                    arr[r[3]]=true;
                }
            }
        }else{
            for(auto i=0;i<num_hashes;i++){
                auto res=murmurhash3_32!k(value,i);
                res=cast(uint)((cast(ulong)  res* cast(ulong) array_size) >> 32);
                arr[res]=true;
            }
        }
    }
    bool maybe_present(string value){
        static if(__traits(targetHasFeature, "sse2")){
            static if(__traits(targetHasFeature, "avx2")){
                for(auto i=0;i<num_hashes-8;i+=8){
                    auto res=murmurhash3_32_8seed!k(value,i,i+1,i+2,i+3,i+4,i+5,i+6,i+7);

                    __vector(ulong[8]) r;
                    r[0]=res[0];r[1]=res[1];r[2]=res[2];r[3]=res[3];
                    r[4]=res[4];r[5]=res[5];r[6]=res[6];r[7]=res[7];
                    r *=cast(ulong) array_size;
                    __vector(ulong[8]) s=[32,32,32,32,32,32,32,32];
                    r >>=s;

                    if((arr[r[0]] & arr[r[1]] & arr[r[2]] & arr[r[3]] &
                        arr[r[4]] & arr[r[5]] & arr[r[6]] & arr[r[7]])^1){
                        return false;
                    }
                }
            }else{
                for(auto i=0;i<num_hashes-4;i+=4){
                    auto res=murmurhash3_32_4seed!k(value,i,i+1,i+2,i+3);

                    __vector(ulong[4]) r;
                    r[0]=res[0];r[1]=res[1];r[2]=res[2];r[3]=res[3];
                    r *=cast(ulong) array_size;
                    __vector(ulong[4]) s=[32,32,32,32];
                    r >>=s;

                    if((arr[r[0]] & arr[r[1]] & arr[r[2]] & arr[r[3]])^1){
                        return false;
                    }
                }
            }
            return true;
        }else{
            for(auto i=0;i<num_hashes;i++){
                auto res=murmurhash3_32!k(value,i);
                res=cast(uint)((cast(ulong)  res* cast(ulong) array_size) >> 32);
                if(arr[res]^1){
                    return false;
                }
            }
            return true;
        }
    }
}
unittest{
    import std.stdio;
    writeln("SSE ",__traits(targetHasFeature, "sse2"));
    writeln("AVX2 ",__traits(targetHasFeature, "avx2"));
    BloomFilter bf =BloomFilter(2,0.001);
    assert(bf.maybe_present("not")==false);
    assert(bf.maybe_present("foo")==false);
    assert(bf.maybe_present("asbdfasdfasdfasd")==false);
    bf.insert("abc");
    assert(bf.maybe_present("abc"));
}
unittest{
    import std.datetime.stopwatch:StopWatch,AutoStart;
    import std.stdio;
    StopWatch s = StopWatch(AutoStart.no);
    auto bf=BloomFilter(1000,0.01);
    s.start;
    for(auto i=0;i<10_000;i++){
        bf.insert("GACTAGCTACGATCC");
    }
    s.peek.total!"usecs".writeln;
    s.reset;
    auto bf2=BloomFilter(1000,0.01);
    s.start;
    for(auto i=0;i<10_000;i++){
        bf2.insert("GACTAGCTACGATCC");
    }
    s.peek.total!"usecs".writeln;
    s.reset;
    auto bf3=BloomFilter(1000,0.01);
    s.start;
    for(auto i=0;i<10_000;i++){
        bf3.insert("GACTAGCTACGATCC");
    }
    s.peek.total!"usecs".writeln;
    s.reset;
}
unittest{
    import std.datetime.stopwatch:StopWatch,AutoStart;
    import std.stdio;
    StopWatch s = StopWatch(AutoStart.no);
    auto bf=BloomFilterK!15(1000,0.01);
    s.start;
    for(auto i=0;i<10_000;i++){
        bf.insert("GACTAGCTACGATCC");
    }
    s.peek.total!"usecs".writeln;
    s.reset;
    auto bf2=BloomFilterK!15(1000,0.01);
    s.start;
    for(auto i=0;i<10_000;i++){
        bf2.insert("GACTAGCTACGATCC");
    }
    s.peek.total!"usecs".writeln;
    s.reset;
    auto bf3=BloomFilterK!15(1000,0.01);
    s.start;
    for(auto i=0;i<10_000;i++){
        bf3.insert("GACTAGCTACGATCC");
    }
    s.peek.total!"usecs".writeln;
    s.reset;
}