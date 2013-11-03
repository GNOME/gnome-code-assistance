namespace Gca
{

public delegate void WithSemanticValueCallback(SourceIndex diagnostics);

public interface SemanticValueSupport : Gca.Document
{
	public void with_semantics(WithSemanticValueCallback callback)
	{
		var sems = begin_semantics();
		callback(sems);

		end_semantics();
	}

	public abstract SourceIndex begin_semantics();
	public abstract void end_semantics();

	public signal void semantic_values_updated();
}

}

/* vi:ex:ts=4 */
