struct MurmurHash3_128_32
{
    enum blockSize = 128; // Number of bits of the hashed value.
    size_t element_count; // The number of full elements pushed, this is used for finalization.
    private enum uint c1 = 0x239b961b;
    private enum uint c2 = 0xab0e9789;
    private enum uint c3 = 0x38b34ae5;
    private enum uint c4 = 0xa1e38b93;
    private uint h4, h3, h2, h1;

    alias Element = uint[4]; /// The element type for 128-bit implementation.

    this(uint seed4, uint seed3, uint seed2, uint seed1) pure nothrow @nogc
    {
        h4 = seed4;
        h3 = seed3;
        h2 = seed2;
        h1 = seed1;
    }

    this(uint seed) pure nothrow @nogc
    {
        h4 = h3 = h2 = h1 = seed;
    }

    /++
    Adds a single Element of data without increasing element_count.
    Make sure to increase `element_count` by `Element.sizeof` for each call to `putElement`.
    +/
    void putElement(Element block) pure nothrow @nogc
    {
        h1 = update(h1, block[0], h2, c1, c2, 15, 19, 0x561ccd1bU);
        h2 = update(h2, block[1], h3, c2, c3, 16, 17, 0x0bcaa747U);
        h3 = update(h3, block[2], h4, c3, c4, 17, 15, 0x96cd1c35U);
        h4 = update(h4, block[3], h1, c4, c1, 18, 13, 0x32ac3b17U);
    }

    /// Put remainder bytes. This must be called only once after `putElement` and before `finalize`.
    void putRemainder(scope const(ubyte[]) data...) pure nothrow @nogc
    {
        assert(data.length < Element.sizeof);
        assert(data.length >= 0);
        element_count += data.length;
        uint k1 = 0;
        uint k2 = 0;
        uint k3 = 0;
        uint k4 = 0;

        final switch (data.length & 15)
        {
        case 15:
            k4 ^= data[14] << 16;
            goto case;
        case 14:
            k4 ^= data[13] << 8;
            goto case;
        case 13:
            k4 ^= data[12] << 0;
            h4 ^= shuffle(k4, c4, c1, 18);
            goto case;
        case 12:
            k3 ^= data[11] << 24;
            goto case;
        case 11:
            k3 ^= data[10] << 16;
            goto case;
        case 10:
            k3 ^= data[9] << 8;
            goto case;
        case 9:
            k3 ^= data[8] << 0;
            h3 ^= shuffle(k3, c3, c4, 17);
            goto case;
        case 8:
            k2 ^= data[7] << 24;
            goto case;
        case 7:
            k2 ^= data[6] << 16;
            goto case;
        case 6:
            k2 ^= data[5] << 8;
            goto case;
        case 5:
            k2 ^= data[4] << 0;
            h2 ^= shuffle(k2, c2, c3, 16);
            goto case;
        case 4:
            k1 ^= data[3] << 24;
            goto case;
        case 3:
            k1 ^= data[2] << 16;
            goto case;
        case 2:
            k1 ^= data[1] << 8;
            goto case;
        case 1:
            k1 ^= data[0] << 0;
            h1 ^= shuffle(k1, c1, c2, 15);
            goto case;
        case 0:
        }
    }

    /// Incorporate `element_count` and finalizes the hash.
    void finalize() pure nothrow @nogc
    {
        h1 ^= element_count;
        h2 ^= element_count;
        h3 ^= element_count;
        h4 ^= element_count;

        h1 += h2;
        h1 += h3;
        h1 += h4;
        h2 += h1;
        h3 += h1;
        h4 += h1;

        h1 = fmix(h1);
        h2 = fmix(h2);
        h3 = fmix(h3);
        h4 = fmix(h4);

        h1 += h2;
        h1 += h3;
        h1 += h4;
        h2 += h1;
        h3 += h1;
        h4 += h1;
    }

    /// Returns the hash as an uint[4] value.
    Element get() pure nothrow @nogc
    {
        return [h1, h2, h3, h4];
    }

    /// Returns the current hashed value as an ubyte array.
    ubyte[16] getBytes() pure nothrow @nogc
    {
        return cast(typeof(return)) get();
    }

    /++
    Pushes an array of elements at once. It is more efficient to push as much data as possible in a single call.
    On platforms that do not support unaligned reads (MIPS or old ARM chips), the compiler may produce slower code to ensure correctness.
    +/
    void putElements(scope const(Element[]) elements...) pure nothrow @nogc
    {
        foreach (const block; elements)
        {
            putElement(block);
        }
        element_count += elements.length * Element.sizeof;
    }

    //-------------------------------------------------------------------------
    // MurmurHash3 utils
    //-------------------------------------------------------------------------

    private T rotl(T)(T x, uint y)
    in
    {
        import std.traits : isUnsigned;

        static assert(isUnsigned!T);
        debug assert(y >= 0 && y <= (T.sizeof * 8));
    }
    do
    {
        return ((x << y) | (x >> ((T.sizeof * 8) - y)));
    }

    private T shuffle(T)(T k, T c1, T c2, ubyte r1)
    {
        import std.traits : isUnsigned;

        static assert(isUnsigned!T);
        k *= c1;
        k = rotl(k, r1);
        k *= c2;
        return k;
    }

    private T update(T)(ref T h, T k, T mixWith, T c1, T c2, ubyte r1, ubyte r2, T n)
    {
        import std.traits : isUnsigned;

        static assert(isUnsigned!T);
        h ^= shuffle(k, c1, c2, r1);
        h = rotl(h, r2);
        h += mixWith;
        return h * 5 + n;
    }

    private uint fmix(uint h) pure nothrow @nogc
    {
        h ^= h >> 16;
        h *= 0x85ebca6b;
        h ^= h >> 13;
        h *= 0xc2b2ae35;
        h ^= h >> 16;
        return h;
    }

    private ulong fmix(ulong k) pure nothrow @nogc
    {
        k ^= k >> 33;
        k *= 0xff51afd7ed558ccd;
        k ^= k >> 33;
        k *= 0xc4ceb9fe1a85ec53;
        k ^= k >> 33;
        return k;
    }
}
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
    // "a" : "B269253C",
    // "ab" : "5FD7BF9B",
    // "abc" : "FA93DDB3",
    assert(hash!MurmurHash3_32("")==hash!(MurmurHash3!32)(""));
    assert(hash!MurmurHash3_32("a")==hash!(MurmurHash3!32)("a"));
    assert(hash!MurmurHash3_32("ab")==hash!(MurmurHash3!32)("ab"));
    assert(hash!MurmurHash3_32("abc")==hash!(MurmurHash3!32)("abc"));
    assert(hash!MurmurHash3_32("abcd")==hash!(MurmurHash3!32)("abcd"));
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
