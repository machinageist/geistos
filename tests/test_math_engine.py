import math
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "lib"))
from geistos_math import MathError, evaluate, sample


class MathEngineTests(unittest.TestCase):
    def test_standard_arithmetic_and_precedence(self):
        self.assertEqual(evaluate("2 + 3 * 4"), 14.0)
        self.assertEqual(evaluate("(2 + 3) * 4"), 20.0)
        self.assertEqual(evaluate("25%"), 0.25)
        self.assertEqual(evaluate("2^3"), 8.0)

    def test_scientific_functions_and_degrees(self):
        self.assertAlmostEqual(evaluate("sin(pi / 2)"), 1.0)
        self.assertAlmostEqual(evaluate("sin(90)", angle_mode="degrees"), 1.0)
        self.assertAlmostEqual(evaluate("log(1000)"), 3.0)
        self.assertEqual(evaluate("factorial(5)"), 120.0)

    def test_graph_expression_and_invalid_points(self):
        points = sample("y = sin(x)", -math.pi, math.pi, 5)
        self.assertEqual(len(points), 5)
        self.assertAlmostEqual(points[2].y, 0.0)
        broken = sample("1 / (x - 1)", 0.0, 2.0, 3)
        self.assertIsNone(broken[1].y)

    def test_rejects_unsafe_or_invalid_input(self):
        with self.assertRaises(MathError):
            evaluate("__import__('os').system('id')")
        with self.assertRaises(MathError):
            evaluate("1 / 0")
        with self.assertRaises(MathError):
            evaluate("unknown(1)")


if __name__ == "__main__":
    unittest.main()
