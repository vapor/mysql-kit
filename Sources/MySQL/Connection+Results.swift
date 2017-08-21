import Core

class ResultsBuilder : Stream {
    func inputStream(_ input: Packet) {
        
    }
    
    var outputStream: ((Results) -> ())?
    
    var errorStream: BaseStream.ErrorHandler?
    
    typealias Input = Packet
    typealias Output = Results
}

class Results {
    
}
