namespace EKOS.Graph.Core;

public class GraphValidator
{
    public ValidationResult Validate(Graph graph)
    {
        var result = new ValidationResult();

        ValidateNodeUniqueness(graph, result);
        ValidateEdgeIntegrity(graph, result);

        return result;
    }

    private void ValidateNodeUniqueness(Graph graph, ValidationResult result)
    {
        var duplicates = graph.Nodes
            .GroupBy(n => n.Id)
            .Where(g => g.Count() > 1)
            .ToList();

        if (duplicates.Any())
            result.Errors.Add($"Duplicate nodes detected: {duplicates.Count}");
    }

    private void ValidateEdgeIntegrity(Graph graph, ValidationResult result)
    {
        var invalidEdges = graph.Edges
            .Where(e =>
                !graph.Nodes.Any(n => n.Id == e.SourceId) ||
                !graph.Nodes.Any(n => n.Id == e.TargetId))
            .ToList();

        if (invalidEdges.Any())
            result.Errors.Add($"Invalid edges detected: {invalidEdges.Count}");
    }
}

public class ValidationResult
{
    public List<string> Errors { get; set; } = new();
    public bool IsValid => Errors.Count == 0;
}