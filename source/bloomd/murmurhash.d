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
struct MurmurHash3_32
{
    enum blockSize = 32; // Number of bits of the hashed value.
    size_t element_count; // The number of full elements pushed, this is used for finalization.
    private enum uint c1 = 0xcc9e2d51;
    private enum uint c2 = 0x1b873593;
    private uint h1;
    alias Element = uint; 

    this(uint seed)
    {
        h1 = seed;
    }
    /++
    Adds a single Element of data without increasing `element_count`.
    Make sure to increase `element_count` by `Element.sizeof` for each call to `putElement`.
    +/
    pragma(inline,true)
    void putElement(uint block) pure nothrow @nogc
    {

        block *= c1;

        block = ((block << 15) | (block >> ((uint.sizeof * 8) - 15)));
        block *= c2;
        h1 ^=block;

        h1 =((h1 << 13) | (h1 >> ((uint.sizeof * 8) - 13)));
        h1 = h1 * 5 + 0xe6546b64U;
    }
    pragma(inline,true)
    void putElements(scope const(uint[]) elements...) pure nothrow @nogc
    {
        foreach (const block; elements)
        {
            putElement(block);
        }
        element_count += elements.length * uint.sizeof;
    }
    pragma(inline,true)
    /// Put remainder bytes. This must be called only once after `putElement` and before `finalize`.
    void putRemainder(scope const(ubyte[]) data...) pure nothrow @nogc
    {
        assert(data.length < uint.sizeof);
        assert(data.length >= 0);
        element_count += data.length;
        uint k1 = 0;
        final switch (data.length & 3)
        {
        case 3:
            k1 ^= data[2] << 16;
            goto case;
        case 2:
            k1 ^= data[1] << 8;
            goto case;
        case 1:
            k1 ^= data[0];

            // h1 ^= shuffle(k1, c1, c2, 15);
            // private T shuffle(T)(T k, T c1, T c2, ubyte r1)

            k1 *= c1;

            // k1 = rotl(k1, 15);
            //private T rotl(T)(T x, uint y)

            k1 = ((k1 << 15) | (k1 >> ((uint.sizeof * 8) - 15)));
            k1 *= c2;
            h1 ^= k1;
            goto case;
        case 0:
        }
    }
    pragma(inline,true)
    /// Incorporate `element_count` and finalizes the hash.
    void finalize() pure nothrow @nogc
    {
        h1 ^= element_count;
        // h1 = fmix(h1);
        h1 ^= h1 >> 16;
        h1 *= 0x85ebca6b;
        h1 ^= h1 >> 13;
        h1 *= 0xc2b2ae35;
        h1 ^= h1 >> 16;
    }
    pragma(inline,true)
    /// Returns the hash as an uint value.
    uint get() pure nothrow @nogc
    {
        return h1;
    }
    pragma(inline,true)
    /// Returns the current hashed value as an ubyte array.
    ubyte[4] getBytes() pure nothrow @nogc
    {
        return cast(typeof(return)) cast(uint[1])[get()];
    }
    auto hash(string data)
    {
        immutable elements = data.length / Element.sizeof;
        this.putElements(cast(const(Element)[]) data[0 .. elements * Element.sizeof]);
        this.putRemainder(cast(const(ubyte)[]) data[elements * Element.sizeof .. $]);
        this.finalize();
        return this.get();
    }
}
string putElementStrMix(){
    return "block *= c1;\n"~
    "block = ((block << 15) | (block >> ((uint.sizeof * 8) - 15)));\n"~
    "block *= c2;\n"~
    "h1 ^=block;\n"~
    "h1 =((h1 << 13) | (h1 >> ((uint.sizeof * 8) - 13)));\n"~
    "h1 = h1 * 5 + 0xe6546b64U;";
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
            "auto i="~n~"%4;\n"~
            "auto j="~n~"%4;\n"~
            "if(i==3){\n"~
                "c=cast(uint)str[(i-j)+2];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;k2[4]=c;k2[5]=c;k2[6]=c;k2[7]=c;\n"~
                "k1 = k1 ^ (k2 << SL16);"~
                "i--;\n"~
            "}else if(i==2){\n"~
                "c=cast(uint)str[(i-j)+1];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;k2[4]=c;k2[5]=c;k2[6]=c;k2[7]=c;\n"~
                "k1 = k1 ^ (k2 << SL8);";
                "i--;\n"~
            "}else if(i==1){\n"~
                "c=cast(uint)str[(i-j)];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;k2[4]=c;k2[5]=c;k2[6]=c;k2[7]=c;\n"~
                "k1 = k1 ^ k2;\n"~
                "k1 *= c1;\n"~
                "k1 = ((k1 << ROTSL15) | (k1 >> ROTSR15));\n"~
                "k1 *= c2;\n"~
                "h1 ^= k1;\n"~
            "}\n";
        }else{
            string ret="__vector(uint[4]) k1;\n"~
            "__vector(uint[4]) k2;\n"~
            "uint c;\n"~
            "auto i="~n~"%4;\n"~
            "auto j="~n~"%4;\n"~
            "if(i==3){\n"~
                "c=cast(uint)str[(i-j)+2];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;\n"~
                "k1 = k1 ^ (k2 << SL16);"~
                "i--;\n"~
            "}else if(i==2){\n"~
                "c=cast(uint)str[(i-j)+1];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;\n"~
                "k1 = k1 ^ (k2 << SL8);"~
                "i--;\n"~
            "}else if(i==1){\n"~
                "c=cast(uint)str[(i-j)];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;\n"~
                "k1 = k1 ^ k2;\n"~
                "k1 *= c1;\n"~
                "k1 = ((k1 << ROTSL15) | (k1 >> ROTSR15));\n"~
                "k1 *= c2;\n"~
                "h1 ^= k1;\n"~
            "}\n";
        }
    }else{
        string ret="uint k1 = 0;\n"~
        "auto i="~n~"%4;\n"~
        "auto j="~n~"%4;\n"~
        "if(i==3){\n"~
            "k1 ^= cast(ubyte)str[(i-j)+2] << 16;\n";
            "i--;\n"~
        "}else if(i==2){\n"~
            "k1 ^= cast(ubyte)str[(i-j)+1] << 8;\n";
            "i--;\n"~
        "}else if(i==1){\n"~
            "k1 ^= cast(ubyte)str[(i-j)];\n"~
            "k1 *= c1;\n"~
            "k1 = ((k1 << 15) | (k1 >> ((uint.sizeof * 8) - 15)));\n"~
            "k1 *= c2;\n"~
            "h1 ^= k1;\n"~
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
            }else if(i==2){
                ret~="c=cast(uint)str["~(n-n%4).to!string~"+1];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;k2[4]=c;k2[5]=c;k2[6]=c;k2[7]=c;\n"~
                "k1 = k1 ^ (k2 << SL8);";
                i--;
            }else if(i==1){
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
            }else if(i==2){
                ret~="c=cast(uint)str["~(n-n%4).to!string~"+1];\n"~
                "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;\n"~
                "k1 = k1 ^ (k2 << SL8);";
                i--;
            }else if(i==1){
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
        }else if(i==2){
            ret~="k1 ^= cast(ubyte)str["~(n-n%4).to!string~"+1] << 8;\n";
            i--;
        }else if(i==1){
            ret~="k1 ^= cast(ubyte)str["~(n-n%4).to!string~"];\n"~
            "k1 *= c1;\n"~
            "k1 = ((k1 << 15) | (k1 >> ((uint.sizeof * 8) - 15)));\n"~
            "k1 *= c2;\n"~
            "h1 ^= k1;\n";
        }
    }
    return ret;
}
string finalize(ulong k) {
    import std.conv:to;
    static if(__traits(targetHasFeature, "sse2")){
        static if(__traits(targetHasFeature, "avx2")){
            return "__vector(uint[8]) e=["~k.to!string~","~k.to!string~","~k.to!string~","~k.to!string~","~k.to!string~","~k.to!string~","~k.to!string~","~k.to!string~"];\n"~
            "h1 ^= e;\n"~
            "h1 ^= h1 >> SL16;\n"~
            "h1 *= 0x85ebca6b;\n"~
            "h1 ^= h1 >> SL13;\n"~
            "h1 *= 0xc2b2ae35;\n"~
            "h1 ^= h1 >> SL16;\n";
        }else{
            return "__vector(uint[4]) e=["~k.to!string~","~k.to!string~","~k.to!string~","~k.to!string~"];\n"~
            "h1 ^= e;\n"~
            "h1 ^= h1 >> SL16;\n"~
            "h1 *= 0x85ebca6b;\n"~
            "h1 ^= h1 >> SL13;\n"~
            "h1 *= 0xc2b2ae35;\n"~
            "h1 ^= h1 >> SL16;\n";
        }
    }else{
        return "h1 ^= "~k.to!string~";\n"~
        "h1 ^= h1 >> 16;\n"~
        "h1 *= 0x85ebca6b;\n"~
        "h1 ^= h1 >> 13;\n"~
        "h1 *= 0xc2b2ae35;\n"~
        "h1 ^= h1 >> 16;\n";
    }
}
pragma(inline,true)
auto murmurhash3_32(string str,uint seed1=0,uint seed2=0,uint seed3=0,uint seed4=0,uint seed5=0,uint seed6=0,uint seed7=0,uint seed8=0){
    return murmurhash3_32!0(str, seed1, seed2, seed3, seed4, seed5, seed6, seed7, seed8);
}
pragma(inline,true)
auto murmurhash3_32(ulong k)(string str,uint seed1=0,uint seed2=0,uint seed3=0,uint seed4=0,uint seed5=0,uint seed6=0,uint seed7=0,uint seed8=0){
    assert(str.length==k);
    static if(__traits(targetHasFeature, "sse2")){
        static if(__traits(targetHasFeature, "avx2")){
            uint c1 = 0xcc9e2d51;
            uint c2 = 0x1b873593;
            __vector(uint[8]) SL16 = [16,16,16,16,16,16,16,16];
            __vector(uint[8]) SL13 = [13,13,13,13,13,13,13,13];
            __vector(uint[8]) SL8 = [8,8,8,8,8,8,8,8];
            __vector(uint[8]) ROTSL15 = [15,15,15,15,15,15,15,15];
            __vector(uint[8]) ROTSR15 = [(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15];
            __vector(uint[8]) ROTSL13 = [13,13,13,13,13,13,13,13];
            __vector(uint[8]) ROTSR13 = [(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13];
            __vector(uint[8]) h1;
            __vector(uint[8]) block_arr;
            uint block;
            h1[0]=seed1;h1[1]=seed2;h1[2]=seed3;h1[3]=seed4;h1[4]=seed5;h1[5]=seed6;h1[6]=seed7;h1[7]=seed8;
        }else{
            uint c1 = 0xcc9e2d51;
            uint c2 = 0x1b873593;
            __vector(uint[4]) SL16 = [16,16,16,16];
            __vector(uint[4]) SL13 = [13,13,13,13];
            __vector(uint[4]) SL8 = [8,8,8,8];
            __vector(uint[4]) ROTSL15 = [15,15,15,15];
            __vector(uint[4]) ROTSR15 = [(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15];
            __vector(uint[4]) ROTSL13 = [13,13,13,13];
            __vector(uint[4]) ROTSR13 = [(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13];
            __vector(uint[4]) h1;
            __vector(uint[4]) block_arr;
            uint block;
            h1[0]=seed1;h1[1]=seed2;h1[2]=seed3;h1[3]=seed4;
        }
    }else{
        enum uint c1 = 0xcc9e2d51;
        enum uint c2 = 0x1b873593;
        uint h1=seed1;
        uint block;
    }
    static if(k==0){
        mixin(putElement("str.length"));
        mixin(putRemainder("str.length"));
    }else{
        mixin(unrollPutElement(k));
        mixin(unrollPutRemainder(k));
    }
    mixin(finalize(k));
    return h1;
}
struct MurmurHash3_32_4seed
{

    uint element_count; // The number of full elements pushed, this is used for finalization.
    private uint c1 = 0xcc9e2d51;
    private uint c2 = 0x1b873593;
    private __vector(uint[4]) SL16 = [16,16,16,16];
    private __vector(uint[4]) SL13 = [13,13,13,13];
    private __vector(uint[4]) SL8 = [8,8,8,8];
    private __vector(uint[4]) ROTSL15 = [15,15,15,15];
    private __vector(uint[4]) ROTSR15 = [(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15];
    private __vector(uint[4]) ROTSL13 = [13,13,13,13];
    private __vector(uint[4]) ROTSR13 = [(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13];
    private __vector(uint[4]) h1;
    alias Element = uint;

    this(uint seed1,uint seed2,uint seed3,uint seed4)
    {
        h1[0]=seed1;h1[1]=seed2;h1[2]=seed3;h1[3]=seed4;
    }
    /++
    Adds a single Element of data without increasing `element_count`.
    Make sure to increase `element_count` by `Element.sizeof` for each call to `putElement`.
    +/
    pragma(inline,true)
    void putElement(uint block) pure nothrow @nogc
    {
        __vector(uint[4]) block_arr;//=[block,block,block,block];
        block_arr[0]=block;block_arr[1]=block;block_arr[2]=block;block_arr[3]=block;

        block_arr = block_arr * c1;

        block_arr = ((block_arr << ROTSL15) | (block_arr >> ROTSR15));
        block_arr = block_arr * c2;
        h1 ^=block_arr;

        h1 =((h1 << ROTSL13) | (h1 >> ROTSR13));

        h1 = h1 * 5 + 0xe6546b64U;
    }
    pragma(inline,true)
    void putElements(scope const(uint[]) elements...) pure nothrow @nogc
    {
        foreach (const block; elements)
        {
            putElement(block);
        }
        element_count += elements.length * uint.sizeof;
    }
    pragma(inline,true)
    /// Put remainder bytes. This must be called only once after `putElement` and before `finalize`.
    void putRemainder(scope const(ubyte[]) data...) pure nothrow @nogc
    {
        assert(data.length < uint.sizeof);
        assert(data.length >= 0);
        element_count += data.length;
        __vector(uint[4]) k1;
        __vector(uint[4]) k2;
        final switch (data.length & 3)
        {
        case 3:

            k2[0]=data[2];k2[1]=data[2];k2[2]=data[2];k2[3]=data[2];
            k1 = k1 ^ (k2 << SL16);
            goto case;
        case 2:
            k2[0]=data[1];k2[1]=data[1];k2[2]=data[1];k2[3]=data[1];
            k1 = k1 ^ (k2 << SL8);
            goto case;
        case 1:
            k2[0]=data[0];k2[1]=data[0];k2[2]=data[0];k2[3]=data[0];
            k1 =k1^k2;

            // h1 ^= shuffle(k1, c1, c2, 15);
            // private T shuffle(T)(T k, T c1, T c2, ubyte r1)

            k1 *= c1;

            // k1 = rotl(k1, 15);
            //private T rotl(T)(T x, uint y)

            k1 = ((k1 << ROTSL15) | (k1 >> ROTSR15));
            k1 *= c2;
            h1 ^= k1;
            goto case;
        case 0:
        }
    }
    pragma(inline,true)
    /// Incorporate `element_count` and finalizes the hash.
    void finalize() pure nothrow @nogc
    {
        __vector(uint[4]) e;
        e[0]=element_count;e[1]=element_count;e[2]=element_count;e[3]=element_count;
        h1 ^= e;
        // h1 = fmix(h1);
        h1 ^= h1 >> SL16;
        h1 *= 0x85ebca6b;
        h1 ^= h1 >> SL13;
        h1 *= 0xc2b2ae35;
        h1 ^= h1 >> SL16;
    }
    pragma(inline,true)
    /// Returns the hash as an uint value.
    __vector(uint[4]) get() pure nothrow @nogc
    {
        return h1;
    }
    pragma(inline,true)
    /// Returns the current hashed value as an ubyte array.
    ubyte[16] getBytes() pure nothrow @nogc
    {
        return cast(typeof(return)) get();
    }
    auto hash(string data)
    {
        immutable elements = data.length / Element.sizeof;
        this.putElements(cast(const(Element)[]) data[0 .. elements * Element.sizeof]);
        this.putRemainder(cast(const(ubyte)[]) data[elements * Element.sizeof .. $]);
        this.finalize();
        return this.get();
    }
}
string putElementStrMix4(){
    return "block_arr[0]=block;block_arr[1]=block;block_arr[2]=block;block_arr[3]=block;\n"~
    "block_arr = block_arr * c1;\n"~
    "block_arr = ((block_arr << ROTSL15) | (block_arr >> ROTSR15));\n"~
    "block_arr = block_arr * c2;\n"~
    "h1 ^=block_arr;\n"~
    "h1 =((h1 << ROTSL13) | (h1 >> ROTSR13));\n"~
    "h1 = h1 * 5 + 0xe6546b64U;\n";    
}
string unrollPutElement4(ulong n){
    import std.conv:to;
    string ret;
    for(auto i=0;i<n;i++){
        ret=ret~"block=*cast(uint*)(str["~i.to!string~"*4.."~i.to!string~"*4+4].ptr);\n"~putElementStrMix4;
    }
    return ret;
}
string putRemainder4(ulong n)
{
    import std.conv:to;
    string ret="__vector(uint[4]) k1;\n"~
    "__vector(uint[4]) k2;\n"~
    "uint c;\n";
    auto i=n%4;
    if(i==3){
        ret~="c=cast(uint)str["~(n-n%4).to!string~"+2];\n"~
        "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;\n"~
        "k1 = k1 ^ (k2 << SL16);";
        i--;
    }else if(i==2){
        ret~="c=cast(uint)str["~(n-n%4).to!string~"+1];\n"~
        "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;\n"~
        "k1 = k1 ^ (k2 << SL8);";
        i--;
    }else if(i==1){
        ret~="c=cast(uint)str["~(n-n%4).to!string~"];\n"~
        "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;\n"~
        "k1 = k1 ^ k2;\n"~
        "k1 *= c1;\n"~
        "k1 = ((k1 << ROTSL15) | (k1 >> ROTSR15));\n"~
        "k1 *= c2;\n"~
        "h1 ^= k1;\n";
    }
    return ret;
}
string finalize4(ulong k) {
    import std.conv:to;
    return "__vector(uint[4]) e=["~k.to!string~","~k.to!string~","~k.to!string~","~k.to!string~"];\n"~
    "h1 ^= e;\n"~
    "h1 ^= h1 >> SL16;\n"~
    "h1 *= 0x85ebca6b;\n"~
    "h1 ^= h1 >> SL13;\n"~
    "h1 *= 0xc2b2ae35;\n"~
    "h1 ^= h1 >> SL16;\n";
}
pragma(inline,true)
auto murmurhash3_32_4seed(ulong k)(string str,uint seed1,uint seed2,uint seed3,uint seed4){
    assert(str.length==k);
    uint c1 = 0xcc9e2d51;
    uint c2 = 0x1b873593;
    __vector(uint[4]) SL16 = [16,16,16,16];
    __vector(uint[4]) SL13 = [13,13,13,13];
    __vector(uint[4]) SL8 = [8,8,8,8];
    __vector(uint[4]) ROTSL15 = [15,15,15,15];
    __vector(uint[4]) ROTSR15 = [(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15];
    __vector(uint[4]) ROTSL13 = [13,13,13,13];
    __vector(uint[4]) ROTSR13 = [(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13];
    __vector(uint[4]) h1;
    __vector(uint[4]) block_arr;
    uint block;
    h1[0]=seed1;h1[1]=seed2;h1[2]=seed3;h1[3]=seed4;
    mixin(unrollPutElement4(k/4));
    mixin(putRemainder4(k));
    mixin(finalize4(k));
    return h1;
}
struct MurmurHash3_32_8seed
{

    uint element_count; // The number of full elements pushed, this is used for finalization.
    private uint c1 = 0xcc9e2d51;
    private uint c2 = 0x1b873593;
    private __vector(uint[8]) SL16 = [16,16,16,16,16,16,16,16];
    private __vector(uint[8]) SL13 = [13,13,13,13,13,13,13,13];
    private __vector(uint[8]) SL8 = [8,8,8,8,8,8,8,8];
    private __vector(uint[8]) ROTSL15 = [15,15,15,15,15,15,15,15];
    private __vector(uint[8]) ROTSR15 = [(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,
        (uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15];
    private __vector(uint[8]) ROTSL13 = [13,13,13,13,13,13,13,13];
    private __vector(uint[8]) ROTSR13 = [(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,
        (uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13];
    private __vector(uint[8]) h1;
    alias Element = uint;

    this(uint seed1,uint seed2,uint seed3,uint seed4,uint seed5,uint seed6,uint seed7,uint seed8)
    {
        h1[0]=seed1;h1[1]=seed2;h1[2]=seed3;h1[3]=seed4;h1[4]=seed5;h1[5]=seed6;h1[6]=seed7;h1[7]=seed8;
    }
    /++
    Adds a single Element of data without increasing `element_count`.
    Make sure to increase `element_count` by `Element.sizeof` for each call to `putElement`.
    +/
    pragma(inline,true)
    void putElement(uint block) pure nothrow @nogc
    {
        __vector(uint[8]) block_arr;//=[block,block,block,block];
        block_arr[0]=block;block_arr[1]=block;block_arr[2]=block;block_arr[3]=block;
        block_arr[4]=block;block_arr[5]=block;block_arr[6]=block;block_arr[7]=block;
        block_arr = block_arr * c1;

        block_arr = ((block_arr << ROTSL15) | (block_arr >> ROTSR15));
        block_arr = block_arr * c2;
        h1 ^=block_arr;

        h1 =((h1 << ROTSL13) | (h1 >> ROTSR13));

        h1 = h1 * 5 + 0xe6546b64U;
    }
    pragma(inline,true)
    void putElements(scope const(uint[]) elements...) pure nothrow @nogc
    {
        foreach (const block; elements)
        {
            putElement(block);
        }
        element_count += elements.length * uint.sizeof;
    }
    pragma(inline,true)
    /// Put remainder bytes. This must be called only once after `putElement` and before `finalize`.
    void putRemainder(scope const(ubyte[]) data...) pure nothrow @nogc
    {
        assert(data.length < uint.sizeof);
        assert(data.length >= 0);
        element_count += data.length;
        __vector(uint[8]) k1;
        __vector(uint[8]) k2;
        final switch (data.length & 3)
        {
        case 3:

            k2[0]=data[2];k2[1]=data[2];k2[2]=data[2];k2[3]=data[2];
            k2[4]=data[2];k2[5]=data[2];k2[6]=data[2];k2[7]=data[2];
            k1 = k1 ^ (k2 << SL16);
            goto case;
        case 2:
            k2[0]=data[1];k2[1]=data[1];k2[2]=data[1];k2[3]=data[1];
            k2[4]=data[1];k2[5]=data[1];k2[6]=data[1];k2[7]=data[1];
            k1 = k1 ^ (k2 << SL8);
            goto case;
        case 1:
            k2[0]=data[0];k2[1]=data[0];k2[2]=data[0];k2[3]=data[0];
            k2[4]=data[0];k2[5]=data[0];k2[6]=data[0];k2[7]=data[0];
            k1 =k1^k2;

            // h1 ^= shuffle(k1, c1, c2, 15);
            // private T shuffle(T)(T k, T c1, T c2, ubyte r1)

            k1 *= c1;

            // k1 = rotl(k1, 15);
            //private T rotl(T)(T x, uint y)

            k1 = ((k1 << ROTSL15) | (k1 >> ROTSR15));
            k1 *= c2;
            h1 ^= k1;
            goto case;
        case 0:
        }
    }
    pragma(inline,true)
    /// Incorporate `element_count` and finalizes the hash.
    void finalize() pure nothrow @nogc
    {
        __vector(uint[8]) e;
        e[0]=element_count;e[1]=element_count;e[2]=element_count;e[3]=element_count;
        e[4]=element_count;e[5]=element_count;e[6]=element_count;e[7]=element_count;
        h1 ^= e;
        // h1 = fmix(h1);
        h1 ^= h1 >> SL16;
        h1 *= 0x85ebca6b;
        h1 ^= h1 >> SL13;
        h1 *= 0xc2b2ae35;
        h1 ^= h1 >> SL16;
    }
    pragma(inline,true)
    /// Returns the hash as an uint value.
    __vector(uint[8]) get() pure nothrow @nogc
    {
        return h1;
    }
    pragma(inline,true)
    /// Returns the current hashed value as an ubyte array.
    ubyte[32] getBytes() pure nothrow @nogc
    {
        return cast(typeof(return)) get();
    }
    auto hash(string data)
    {
        immutable elements = data.length / Element.sizeof;
        this.putElements(cast(const(Element)[]) data[0 .. elements * Element.sizeof]);
        this.putRemainder(cast(const(ubyte)[]) data[elements * Element.sizeof .. $]);
        this.finalize();
        return this.get();
    }
}
string putElementStrMix8(){
    return "block_arr[0]=block;block_arr[1]=block;block_arr[2]=block;block_arr[3]=block;block_arr[4]=block;block_arr[5]=block;block_arr[6]=block;block_arr[7]=block;\n"~
    "block_arr = block_arr * c1;\n"~
    "block_arr = ((block_arr << ROTSL15) | (block_arr >> ROTSR15));\n"~
    "block_arr = block_arr * c2;\n"~
    "h1 ^=block_arr;\n"~
    "h1 =((h1 << ROTSL13) | (h1 >> ROTSR13));\n"~
    "h1 = h1 * 5 + 0xe6546b64U;\n";    
}
string unrollPutElement8(ulong n){
    import std.conv:to;
    string ret;
    for(auto i=0;i<n;i++){
        ret=ret~"block=*cast(uint*)(str["~i.to!string~"*4.."~i.to!string~"*4+4].ptr);\n"~putElementStrMix8;
    }
    return ret;
}
string putRemainder8(ulong n)
{
    import std.conv:to;
    string ret="__vector(uint[8]) k1;\n"~
    "__vector(uint[8]) k2;\n"~
    "uint c;\n";
    auto i=n%4;
    if(i==3){
        ret~="c=cast(uint)str["~(n-n%4).to!string~"+2];\n"~
        "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;k2[4]=c;k2[5]=c;k2[6]=c;k2[7]=c;\n"~
        "k1 = k1 ^ (k2 << SL16);";
        i--;
    }else if(i==2){
        ret~="c=cast(uint)str["~(n-n%4).to!string~"+1];\n"~
        "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;k2[4]=c;k2[5]=c;k2[6]=c;k2[7]=c;\n"~
        "k1 = k1 ^ (k2 << SL8);";
        i--;
    }else if(i==1){
        ret~="c=cast(uint)str["~(n-n%4).to!string~"];\n"~
        "k2[0]=c;k2[1]=c;k2[2]=c;k2[3]=c;k2[4]=c;k2[5]=c;k2[6]=c;k2[7]=c;\n"~
        "k1 = k1 ^ k2;\n"~
        "k1 *= c1;\n"~
        "k1 = ((k1 << ROTSL15) | (k1 >> ROTSR15));\n"~
        "k1 *= c2;\n"~
        "h1 ^= k1;\n";
    }
    return ret;
}
string finalize8(ulong k) {
    import std.conv:to;
    return "__vector(uint[8]) e=["~k.to!string~","~k.to!string~","~k.to!string~","~k.to!string~","~k.to!string~","~k.to!string~","~k.to!string~","~k.to!string~"];\n"~
    "h1 ^= e;\n"~
    "h1 ^= h1 >> SL16;\n"~
    "h1 *= 0x85ebca6b;\n"~
    "h1 ^= h1 >> SL13;\n"~
    "h1 *= 0xc2b2ae35;\n"~
    "h1 ^= h1 >> SL16;\n";
}
pragma(inline,true)
auto murmurhash3_32_8seed(ulong k)(string str,uint seed1,uint seed2,uint seed3,uint seed4,uint seed5,uint seed6,uint seed7,uint seed8){
    assert(str.length==k);
    uint c1 = 0xcc9e2d51;
    uint c2 = 0x1b873593;
    __vector(uint[8]) SL16 = [16,16,16,16,16,16,16,16];
    __vector(uint[8]) SL13 = [13,13,13,13,13,13,13,13];
    __vector(uint[8]) SL8 = [8,8,8,8,8,8,8,8];
    __vector(uint[8]) ROTSL15 = [15,15,15,15,15,15,15,15];
    __vector(uint[8]) ROTSR15 = [(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15,(uint.sizeof * 8) - 15];
    __vector(uint[8]) ROTSL13 = [13,13,13,13,13,13,13,13];
    __vector(uint[8]) ROTSR13 = [(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13,(uint.sizeof * 8) - 13];
    __vector(uint[8]) h1;
    __vector(uint[8]) block_arr;
    uint block;
    h1[0]=seed1;h1[1]=seed2;h1[2]=seed3;h1[3]=seed4;h1[4]=seed5;h1[5]=seed6;h1[6]=seed7;h1[7]=seed8;
    mixin(unrollPutElement8(k/4));
    mixin(putRemainder8(k));
    mixin(finalize8(k));
    return h1;
}
private auto hash(H, Element = H.Element)(string data)
{
    H hasher;
    immutable elements = data.length / Element.sizeof;
    hasher.putElements(cast(const(Element)[]) data[0 .. elements * Element.sizeof]);
    hasher.putRemainder(cast(const(ubyte)[]) data[elements * Element.sizeof .. $]);
    hasher.finalize();
    return hasher.get();
}

unittest{
    import std.stdio;
    import std.digest.murmurhash:MurmurHash3;
    import std.datetime.stopwatch:benchmark;
    MurmurHash3_32 h;
    //check that our hash equals the std implementation
    assert(hash!MurmurHash3_32("")==hash!(MurmurHash3!32)(""));
    assert(hash!MurmurHash3_32("a")==hash!(MurmurHash3!32)("a"));
    assert(hash!MurmurHash3_32("ab")==hash!(MurmurHash3!32)("ab"));
    assert(hash!MurmurHash3_32("abc")==hash!(MurmurHash3!32)("abc"));
    assert(hash!MurmurHash3_32("abcd")==hash!(MurmurHash3!32)("abcd"));
    assert(hash!MurmurHash3_32("abcd")==murmurhash3_32!4("abcd",0));
    assert(hash!MurmurHash3_32_4seed("abcd")==murmurhash3_32_4seed!4("abcd",0,0,0,0));
    assert(hash!MurmurHash3_32_8seed("abcd")==murmurhash3_32_8seed!4("abcd",0,0,0,0,0,0,0,0));
    auto h1=MurmurHash3_32(0);
    auto h2=MurmurHash3_32(1);
    auto h3=MurmurHash3_32(2);
    auto h4=MurmurHash3_32(3);
    uint[4] r=[h1.hash("abcd"),h2.hash("abcd"),h3.hash("abcd"),h4.hash("abcd")];
    auto h5=MurmurHash3_32_4seed(0,1,2,3);
    assert(r==cast(uint[4])h5.hash("abcd"));
    auto result=benchmark!(test,testSIMD)(10_000);
    result[0].total!"usecs".writeln;
    result[1].total!"usecs".writeln;
}

void test(){
    auto h1=MurmurHash3_32(0);
    auto h2=MurmurHash3_32(1);
    auto h3=MurmurHash3_32(2);
    auto h4=MurmurHash3_32(3);
    h1.hash("GATAGATCGATCGATCGACTACG");
    h2.hash("GATAGATCGATCGATCGACTACG");
    h3.hash("GATAGATCGATCGATCGACTACG");
    h4.hash("GATAGATCGATCGATCGACTACG");
}
void testSIMD(){
    auto h1=MurmurHash3_32_4seed(0,1,2,3);
    h1.hash("GATAGATCGATCGATCGACTACG");
}
