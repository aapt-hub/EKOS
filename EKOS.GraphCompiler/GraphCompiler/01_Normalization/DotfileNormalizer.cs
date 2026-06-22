using System;
using System.IO;

namespace EKOS.Graph.Core.GraphCompiler.Normalization
{
    public static class DotfileNormalizer
    {
        public static string Normalize(string filename)
        {
            if (string.IsNullOrWhiteSpace(filename))
                throw new ArgumentException("Filename cannot be empty");

            // ✅ CRITICAL RULE: dotfiles keep full identity
            if (filename.StartsWith("."))
            {
                return filename; // .gitignore stays .gitignore
            }

            // standard files
            return Path.GetFileNameWithoutExtension(filename);
        }

        public static bool IsValidNodeId(string id)
        {
            return !string.IsNullOrWhiteSpace(id);
        }
    }
}
