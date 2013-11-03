namespace Gca
{

public abstract class SemanticValue : Object, SourceRangeSupport
{
	public enum Kind
	{
		NONE,
		STRUCT,
		UNION,
		CLASS,
		ENUM,
		FIELD,
		ENUM_VALUE,
		FUNCTION,
		MEMBER_FUNCTION,
		CONSTRUCTOR,
		DESTRUCTOR,
		VARIABLE,
		PARAMETER,
		TYPEDEF,
		NAMESPACE,
		BLOCK
	}

	[Flags]
	public enum ReferenceType
	{
		NONE,
		DECLARATION = 1 << 0,
		REFERENCE = 1 << 1,
		DEFINITION = 1 << 2
	}

	private SourceRange d_range;
	private Kind d_kind;
	private ReferenceType d_rtype;

	public SemanticValue(SourceRange range, Kind kind, ReferenceType rtype)
	{
		d_range = range;
		d_kind = kind;
		d_rtype = rtype;
	}

	public SourceRange? range
	{
		owned get { return d_range; }
	}

	public SourceRange[] ranges
	{
		owned get { return new SourceRange[] {d_range}; }
	}

	public Kind kind
	{
		get { return d_kind; }
	}

	public ReferenceType reference_type
	{
		get { return d_rtype; }
	}

	public SemanticValue? find_child(Kind kind)
	{
		SemanticValue? child = down;

		while (child != null)
		{
			if (child.kind == kind)
			{
				return child;
			}

			child = child.next;
		}

		return child;
	}

	public abstract SemanticValue? definition
	{
		owned get;
	}

	public abstract SemanticValue? declaration
	{
		owned get;
	}

	public abstract int num_references
	{
		get;
	}

	public abstract SemanticValue reference(int idx);

	public abstract SemanticValue? next
	{
		get;
	}

	public abstract SemanticValue? previous
	{
		get;
	}

	public abstract SemanticValue? up
	{
		get;
	}

	public abstract SemanticValue? down
	{
		get;
	}
}

}

/* vi:ex:ts=4 */
