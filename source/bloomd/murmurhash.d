module bloomd.murmurhash;
// Based on the implementation in std.digest.murmurhash
// however optimizations were made to reduce function calls as 
// we are only using the 32-bit variant of murmurhash3.
//
// We also have loop unrolled variants of murmurhash3 for 
// known length string keys. 
//
// There are also 4seed and 8seed versions for using 
// SIMD instructions to generate 4 or 8 different seeded hashes of the 
// same string in parallel.
pragma(inline,true)
auto murmurhash3_32(string str,uint seed1=0,uint seed2=0,uint seed3=0,uint seed4=0,uint seed5=0,uint seed6=0,uint seed7=0,uint seed8=0){
    return murmurhash3_32!0(str, seed1, seed2, seed3, seed4, seed5, seed6, seed7, seed8);
}
pragma(inline,true)
auto murmurhash3_32(ulong k)(string str,uint seed1=0,uint seed2=0,uint seed3=0,uint seed4=0,uint seed5=0,uint seed6=0,uint seed7=0,uint seed8=0){
    // assert(str.length==k);
    uint c1 = 0xcc9e2d51;
    uint c2 = 0x1b873593;
    uint block;
    static if(__traits(targetHasFeature, "sse2")){
        static if(__traits(targetHasFeature, "avx2")){
            __vector(uint[8]) SL16 = [16,16,16,16,16,16,16,16];
            __vector(uint[8]) SL13 = [13,13,13,13,13,13,13,13];
            __vector(uint[8]) SL8 = [8,8,8,8,8,8,8,8];
            __vector(uint[8]) ROTSL15 = [15,15,15,15,15,15,15,15];
            __vector(uint[8]) ROTSR15 = [(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15];
            __vector(uint[8]) ROTSL13 = [13,13,13,13,13,13,13,13];
            __vector(uint[8]) ROTSR13 = [(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13];
            __vector(uint[8]) h1;
            __vector(uint[8]) block_arr;
            h1[0]=seed1;h1[1]=seed2;h1[2]=seed3;h1[3]=seed4;h1[4]=seed5;h1[5]=seed6;h1[6]=seed7;h1[7]=seed8;
        }else{
            __vector(uint[4]) SL16 = [16,16,16,16];
            __vector(uint[4]) SL13 = [13,13,13,13];
            __vector(uint[4]) SL8 = [8,8,8,8];
            __vector(uint[4]) ROTSL15 = [15,15,15,15];
            __vector(uint[4]) ROTSR15 = [(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15];
            __vector(uint[4]) ROTSL13 = [13,13,13,13];
            __vector(uint[4]) ROTSR13 = [(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13];
            __vector(uint[4]) h1;
            __vector(uint[4]) block_arr;
            h1[0]=seed1;h1[1]=seed2;h1[2]=seed3;h1[3]=seed4;
        }
    }else{
        uint h1=seed1;
    }
    static if(k==0){
        mixin(putElement("str.length"));
        mixin(putRemainder("str.length"));
    }else{
        mixin(unrollPutElement(k));
        mixin(unrollPutRemainder(k));
    }
    mixin(finalize("cast(uint)str.length"));
    return h1;
}

string unrollPutElement(ulong n){
    import std.conv:to;
    string ret;
    static if(__traits(targetHasFeature, "sse2")){
        static if(__traits(targetHasFeature, "avx2")){
            for(auto i=0;i<n/4;i++){
                ret=ret~"block=*cast(uint*)(str["~i.to!string~"*4.."~i.to!string~"*4+4].ptr);\n"~
                "block_arr[0]=block;block_arr[1]=block;block_arr[2]=block;block_arr[3]=block;block_arr[4]=block;block_arr[5]=block;block_arr[6]=block;block_arr[7]=block;\n"~
                "block_arr = block_arr * c1;\n"~
                "block_arr = ((block_arr << ROTSL15) | (block_arr >> ROTSR15));\n"~
                "block_arr = block_arr * c2;\n"~
                "h1 ^=block_arr;\n"~
                "h1 =((h1 << ROTSL13) | (h1 >> ROTSR13));\n"~
                "h1 = h1 * 5 + 0xe6546b64U;\n"; 
            }
        }else{
            for(auto i=0;i<n/4;i++){
                ret=ret~"block=*cast(uint*)(str["~i.to!string~"*4.."~i.to!string~"*4+4].ptr);\n"~
                "block_arr[0]=block;block_arr[1]=block;block_arr[2]=block;block_arr[3]=block;\n"~
                "block_arr = block_arr * c1;\n"~
                "block_arr = ((block_arr << ROTSL15) | (block_arr >> ROTSR15));\n"~
                "block_arr = block_arr * c2;\n"~
                "h1 ^=block_arr;\n"~
                "h1 =((h1 << ROTSL13) | (h1 >> ROTSR13));\n"~
                "h1 = h1 * 5 + 0xe6546b64U;\n";
            }
        }
    }else{
        for(auto i=0;i<n/4;i++){
            ret=ret~"block=*cast(uint*)(str["~i.to!string~"*4.."~i.to!string~"*4+4].ptr);\n"~
            "block *= c1;\n"~
            "block = ((block << 15) | (block >> ((uint.sizeof * 8) - 15)));\n"~
            "block *= c2;\n"~
            "h1 ^=block;\n"~
            "h1 =((h1 << 13) | (h1 >> ((uint.sizeof * 8) - 13)));\n"~
            "h1 = h1 * 5 + 0xe6546b64U;";
        }
    }
    return ret;
}
string putElement(string n){
    import std.conv:to;
    string ret;
    static if(__traits(targetHasFeature, "sse2")){
        static if(__traits(targetHasFeature, "avx2")){
            ret="for(auto i=0;i<"~n~"/4;i++){\n"~
                "block=*cast(uint*)(str[i*4..i*4+4].ptr);\n"~
                "block_arr[0]=block;block_arr[1]=block;block_arr[2]=block;block_arr[3]=block;block_arr[4]=block;block_arr[5]=block;block_arr[6]=block;block_arr[7]=block;\n"~
                "block_arr = block_arr * c1;\n"~
                "block_arr = ((block_arr << ROTSL15) | (block_arr >> ROTSR15));\n"~
                "block_arr = block_arr * c2;\n"~
                "h1 ^=block_arr;\n"~
                "h1 =((h1 << ROTSL13) | (h1 >> ROTSR13));\n"~
                "h1 = h1 * 5 + 0xe6546b64U;\n"~ 
            "}\n";
        }else{
            ret="for(auto i=0;i<"~n~"/4;i++){\n"~
                "block=*cast(uint*)(str[i*4..i*4+4].ptr);\n"~
                "block_arr[0]=block;block_arr[1]=block;block_arr[2]=block;block_arr[3]=block;\n"~
                "block_arr = block_arr * c1;\n"~
                "block_arr = ((block_arr << ROTSL15) | (block_arr >> ROTSR15));\n"~
                "block_arr = block_arr * c2;\n"~
                "h1 ^=block_arr;\n"~
                "h1 =((h1 << ROTSL13) | (h1 >> ROTSR13));\n"~
                "h1 = h1 * 5 + 0xe6546b64U;\n"~
            "}\n";
        }
    }else{
        ret="for(auto i=0;i<"~n~"/4;i++){\n"~
            "block=*cast(uint*)(str[i*4..i*4+4].ptr);\n"~
            "block *= c1;\n"~
            "block = ((block << 15) | (block >> ((uint.sizeof * 8) - 15)));\n"~
            "block *= c2;\n"~
            "h1 ^=block;\n"~
            "h1 =((h1 << 13) | (h1 >> ((uint.sizeof * 8) - 13)));\n"~
            "h1 = h1 * 5 + 0xe6546b64U;\n"~
        "}\n";
    }
    return ret;
}
string putRemainder(string n){
    import std.conv:to;
    static if(__traits(targetHasFeature, "sse2")){
        static if(__traits(targetHasFeature, "avx2")){
            string ret="__vector(uint[8]) k1;\n"~
            "__vector(uint[8]) k2;\n"~
            "uint c;\n"~
            "auto j="~n~"%4;\n"~
            "final switch(j&3){\n"~
            "case 3:\n"~
                "c=cast(uint)str[("~n~"-j)+2];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;k2[4]=c;k2[5]=c;k2[6]=c;k2[7]=c;\n"~
                "k1 = k1 ^ (k2 << SL16);"~
                "goto case;\n"~
            "case 2:\n"~
                "c=cast(uint)str[("~n~"-j)+1];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;k2[4]=c;k2[5]=c;k2[6]=c;k2[7]=c;\n"~
                "k1 = k1 ^ (k2 << SL8);\n"~
                "goto case;\n"~
            "case 1:\n"~
                "c=cast(uint)str[("~n~"-j)];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;k2[4]=c;k2[5]=c;k2[6]=c;k2[7]=c;\n"~
                "k1 = k1 ^ k2;\n"~
                "k1 *= c1;\n"~
                "k1 = ((k1 << ROTSL15) | (k1 >> ROTSR15));\n"~
                "k1 *= c2;\n"~
                "h1 ^= k1;\n"~
                "goto case;\n"~
            "case 0:\n"~
            "}\n";
        }else{
            string ret="__vector(uint[4]) k1;\n"~
            "__vector(uint[4]) k2;\n"~
            "uint c;\n"~
            "auto j="~n~"%4;\n"~
            "final switch(j&3){\n"~
            "case 3:\n"~
                "c=cast(uint)str[("~n~"-j)+2];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;\n"~
                "k1 = k1 ^ (k2 << SL16);"~
                "goto case;\n"~
            "case 2:\n"~
                "c=cast(uint)str[("~n~"-j)+1];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;\n"~
                "k1 = k1 ^ (k2 << SL8);"~
                "goto case;\n"~
            "case 1:\n"~
                "c=cast(uint)str[("~n~"-j)];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;\n"~
                "k1 = k1 ^ k2;\n"~
                "k1 *= c1;\n"~
                "k1 = ((k1 << ROTSL15) | (k1 >> ROTSR15));\n"~
                "k1 *= c2;\n"~
                "h1 ^= k1;\n"~
                "goto case;\n"~
            "case 0:\n"~
            "}\n";
        }
    }else{
        string ret="uint k1 = 0;\n"~
        "auto j="~n~"%4;\n"~
        "final switch(j&3){\n"~
        "case 3:\n"~
            "k1 ^= cast(ubyte)str[("~n~"-j)+2] << 16;\n";
            "goto case;\n"~
        "case 2:\n"~
            "k1 ^= cast(ubyte)str[("~n~"-j)+1] << 8;\n";
            "goto case;\n"~
        "case 1:\n"~
            "k1 ^= cast(ubyte)str[("~n~"-j)];\n"~
            "k1 *= c1;\n"~
            "k1 = ((k1 << 15) | (k1 >> ((uint.sizeof * 8) - 15)));\n"~
            "k1 *= c2;\n"~
            "h1 ^= k1;\n"~
            "goto case;\n"~
        "case 0:\n"~
        "}\n";
    }
    return ret;
}
string unrollPutRemainder(ulong n){
    import std.conv:to;
    static if(__traits(targetHasFeature, "sse2")){
        static if(__traits(targetHasFeature, "avx2")){
            string ret="__vector(uint[8]) k1;\n"~
            "__vector(uint[8]) k2;\n"~
            "uint c;\n";
            auto i=n%4;
            if(i==3){
                ret~="c=cast(uint)str["~(n-n%4).to!string~"+2];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;k2[4]=c;k2[5]=c;k2[6]=c;k2[7]=c;\n"~
                "k1 = k1 ^ (k2 << SL16);";
                i--;
            }if(i==2){
                ret~="c=cast(uint)str["~(n-n%4).to!string~"+1];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;k2[4]=c;k2[5]=c;k2[6]=c;k2[7]=c;\n"~
                "k1 = k1 ^ (k2 << SL8);";
                i--;
            }if(i==1){
                ret~="c=cast(uint)str["~(n-n%4).to!string~"];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;k2[4]=c;k2[5]=c;k2[6]=c;k2[7]=c;\n"~
                "k1 = k1 ^ k2;\n"~
                "k1 *= c1;\n"~
                "k1 = ((k1 << ROTSL15) | (k1 >> ROTSR15));\n"~
                "k1 *= c2;\n"~
                "h1 ^= k1;\n";
            }
        }else{
            string ret="__vector(uint[4]) k1;\n"~
            "__vector(uint[4]) k2;\n"~
            "uint c;\n";
            auto i=n%4;
            if(i==3){
                ret~="c=cast(uint)str["~(n-n%4).to!string~"+2];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;\n"~
                "k1 = k1 ^ (k2 << SL16);";
                i--;
            }if(i==2){
                ret~="c=cast(uint)str["~(n-n%4).to!string~"+1];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;\n"~
                "k1 = k1 ^ (k2 << SL8);";
                i--;
            }if(i==1){
                ret~="c=cast(uint)str["~(n-n%4).to!string~"];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;\n"~
                "k1 = k1 ^ k2;\n"~
                "k1 *= c1;\n"~
                "k1 = ((k1 << ROTSL15) | (k1 >> ROTSR15));\n"~
                "k1 *= c2;\n"~
                "h1 ^= k1;\n";
            }
        }
    }else{
        string ret="uint k1 = 0;\n";
        auto i=n%4;
        if(i==3){
            ret~="k1 ^= cast(ubyte)str["~(n-n%4).to!string~"+2] << 16;\n";
            i--;
        }if(i==2){
            ret~="k1 ^= cast(ubyte)str["~(n-n%4).to!string~"+1] << 8;\n";
            i--;
        }if(i==1){
            ret~="k1 ^= cast(ubyte)str["~(n-n%4).to!string~"];\n"~
            "k1 *= c1;\n"~
            "k1 = ((k1 << 15) | (k1 >> ((uint.sizeof * 8) - 15)));\n"~
            "k1 *= c2;\n"~
            "h1 ^= k1;\n";
        }
    }
    return ret;
}
string finalize(string k) {
    import std.conv:to;
    static if(__traits(targetHasFeature, "sse2")){
        static if(__traits(targetHasFeature, "avx2")){
            return "__vector(uint[8]) e;\n"~
            "e[0]="~k~";e[1]="~k~";e[2]="~k~";e[3]="~k~";e[4]="~k~";e[5]="~k~";e[6]="~k~";e[7]="~k~";\n"~
            "h1 ^= e;\n"~
            "h1 ^= h1 >> SL16;\n"~
            "h1 *= 0x85ebca6b;\n"~
            "h1 ^= h1 >> SL13;\n"~
            "h1 *= 0xc2b2ae35;\n"~
            "h1 ^= h1 >> SL16;\n";
        }else{
            return "__vector(uint[4]) e;\n"~
            "e[0]="~k~";e[1]="~k~";e[2]="~k~";e[3]="~k~";\n"~
            "h1 ^= e;\n"~
            "h1 ^= h1 >> SL16;\n"~
            "h1 *= 0x85ebca6b;\n"~
            "h1 ^= h1 >> SL13;\n"~
            "h1 *= 0xc2b2ae35;\n"~
            "h1 ^= h1 >> SL16;\n";
        }
    }else{
        return "h1 ^= "~k~";\n"~
        "h1 ^= h1 >> 16;\n"~
        "h1 *= 0x85ebca6b;\n"~
        "h1 ^= h1 >> 13;\n"~
        "h1 *= 0xc2b2ae35;\n"~
        "h1 ^= h1 >> 16;\n";
    }
}

private auto hash(H, Element = H.Element)(string data,uint seed=0)
{
    H hasher=H(seed);
    immutable elements = data.length / Element.sizeof;
    hasher.putElements(cast(const(Element)[]) data[0 .. elements * Element.sizeof]);
    hasher.putRemainder(cast(const(ubyte)[]) data[elements * Element.sizeof .. $]);
    hasher.finalize();
    return hasher.get();
}

unittest{
    import std.stdio;
    import std.conv:to;
    import std.digest.murmurhash:MurmurHash3;
    import std.datetime.stopwatch:benchmark;
    //check that our hash equals the std implementation
    auto res=murmurhash3_32("");
    assert(res[0]==hash!(MurmurHash3!32)(""));
    res=murmurhash3_32("a");
    assert(res[0]==hash!(MurmurHash3!32)("a"));
    res=murmurhash3_32("ab");
    assert(res[0]==hash!(MurmurHash3!32)("ab"));
    res=murmurhash3_32("abc");
    assert(res[0]==hash!(MurmurHash3!32)("abc"));
    res=murmurhash3_32("abcd");
    assert(res[0]==hash!(MurmurHash3!32)("abcd"));
    res=murmurhash3_32!1("a");
    assert(res[0]==hash!(MurmurHash3!32)("a"));
    res=murmurhash3_32!2("ab");
    assert(res[0]==hash!(MurmurHash3!32)("ab"));
    res=murmurhash3_32!3("abc");
    assert(res[0]==hash!(MurmurHash3!32)("abc"));
    res=murmurhash3_32!4("abcd");
    assert(res[0]==hash!(MurmurHash3!32)("abcd"));
    static if(__traits(targetHasFeature, "sse2")){
        static if(__traits(targetHasFeature, "avx2")){
            __vector(uint[8]) v1;
            uint[8] v2;
        }else{
            __vector(uint[4]) v1;
            uint[4] v2;
        }
    }else{
        uint v1;
        uint v2;
    }
    writeln("SSE2 ",__traits(targetHasFeature, "sse2"));
    writeln("AVX ",__traits(targetHasFeature, "avx"));
    writeln("AVX2 ",__traits(targetHasFeature, "avx2"));
    auto result=benchmark!({v2=test;},{v1=testSIMD;})(100_000);
    writeln((result[0].total!"usecs".to!float/result[1].total!"usecs".to!float),"x improvement");
}

auto test(){
    import std.digest.murmurhash:MurmurHash3;
    static if(__traits(targetHasFeature, "sse2")){
        static if(__traits(targetHasFeature, "avx2")){
            auto h1=hash!(MurmurHash3!32)("GATAGATCGATCGATCGACTACG",0);
            auto h2=hash!(MurmurHash3!32)("GATAGATCGATCGATCGACTACG",1);
            auto h3=hash!(MurmurHash3!32)("GATAGATCGATCGATCGACTACG",2);
            auto h4=hash!(MurmurHash3!32)("GATAGATCGATCGATCGACTACG",3);
            auto h5=hash!(MurmurHash3!32)("GATAGATCGATCGATCGACTACG",4);
            auto h6=hash!(MurmurHash3!32)("GATAGATCGATCGATCGACTACG",5);
            auto h7=hash!(MurmurHash3!32)("GATAGATCGATCGATCGACTACG",6);
            auto h8=hash!(MurmurHash3!32)("GATAGATCGATCGATCGACTACG",7);
            return [h1,h2,h3,h4,h5,h6,h7,h8];
        }else{
            auto h1=hash!(MurmurHash3!32)("GATAGATCGATCGATCGACTACG",0);
            auto h2=hash!(MurmurHash3!32)("GATAGATCGATCGATCGACTACG",1);
            auto h3=hash!(MurmurHash3!32)("GATAGATCGATCGATCGACTACG",2);
            auto h4=hash!(MurmurHash3!32)("GATAGATCGATCGATCGACTACG",3);    
            return [h1,h2,h3,h4];
        }
    }else{
        auto h1=hash!(MurmurHash3!32)("GATAGATCGATCGATCGACTACG",0);    
        return [h1];
    }
}
auto testSIMD(){
    return murmurhash3_32("GATAGATCGATCGATCGACTACG",0,1,2,3,4,5,6,7);
}
