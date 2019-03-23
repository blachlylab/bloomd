import std.stdio;

void main()
{
	writeln("Edit source/app.d to start your project.");
	__vector(ulong[4]) x=[1,2,4,8];
	ul(x);
	x[0].writeln;
	x[1].writeln;
	x[2].writeln;
	x[3].writeln;
}
void ul(ref __vector(ulong[4]) a)
{
    __vector(ulong[4]) s=[1,2,3,4];
    a = a * 5;
}
