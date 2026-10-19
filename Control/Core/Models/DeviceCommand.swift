import Foundation

enum DeviceCommand: Codable, Equatable, Hashable {
    case power(Bool)
    case socketPower(socketIndex: Int, isOn: Bool)
    case brightness(Int)
    case colorTemperature(Int)
    case rgb(r: Int, g: Int, b: Int)
    case scene(String)
    case fanSpeed(Int)
    case fanLed(Bool)
    case fanBoost(Bool)
    case fanSleep(Bool)
    case fanTimer(Int)
    case acTemperature(Double)
    case acMode(ACMode)
    case acFanSpeed(ACFanSpeed)
    case acSwing(Bool)
    case acTurbo(Bool)
    case acEco(Bool)
    case acFlexicool(FlexicoolLevel)
}
