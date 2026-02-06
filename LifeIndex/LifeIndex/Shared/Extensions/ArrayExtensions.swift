extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        let sum = self.reduce(0, +)
        return sum / Double(self.count)
    }
}
