//
//  LazyFishLayout.swift
//  LazyFish
//
//  Created by zjj on 2021/10/8.
//

import Foundation
import UIKit

public enum ValueBinding<T> {
    case constant(T)
    case binding(Binding<T>)
}

internal class Attribute {
    enum _Attribute {
        case alignment([Edge: CGFloat])
        case onAppear(OnAppearBlock?)
    }
    var attrs: [_Attribute] = []
    
    private static var attributeKey: Int = 0
    
    internal static func attribute(from view: UIView) -> Attribute {
        if let obj = objc_getAssociatedObject(view, &attributeKey) as? Attribute {
            return obj
        }
        let newone = Attribute()
        objc_setAssociatedObject(view, &attributeKey, newone, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return newone
    }
}

internal enum SizeFill {
    internal enum Dimension {
        case x, y
    }
    
    case unknown
    case equal(_ size: ValueBinding<CGFloat>)
    // 更多规则未完待续
}

public typealias OnAppearBlock = (UIView) -> Void

public struct Alignment: OptionSet {
    public typealias RawValue = Int
    public let rawValue: RawValue
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    public static let leading = Alignment(rawValue: 1 << 0)
    public static let trailing = Alignment(rawValue: 1 << 1)
    public static let top = Alignment(rawValue: 1 << 2)
    public static let bottom = Alignment(rawValue: 1 << 3)
    public static let allEdges: Alignment = [.leading, .trailing, .top, .bottom]
    
    public static let centerX = Alignment(rawValue: 1 << 4)
    public static let centerY = Alignment(rawValue: 1 << 5)
    public static let center: Alignment = [centerX, centerY]
}

internal enum Edge {
    case top, leading, bottom, trailing, centerX, centerY
}

public extension UIView {
    
    func onAppear(_ action: @escaping OnAppearBlock) -> Self {
        Attribute.attribute(from: self).attrs.append(.onAppear(action))
        return self
    }
    
    func frame(width: CGFloat, height: CGFloat) -> Self {
        Layout.sizeFill(self, width: .equal(.constant(width)), height: .equal(.constant(height)))
        return self
    }
    
    func frame(width: CGFloat) -> Self {
        Layout.sizeFill(self, width: .equal(.constant(width)), height: nil)
        return self
    }
    
    func frame(height: CGFloat) -> Self {
        Layout.sizeFill(self, width: nil, height: .equal(.constant(height)))
        return self
    }
    
    func frame(width: Binding<CGFloat>) -> Self {
        Layout.sizeFill(self, width: .equal(.binding(width)), height: nil)
        return self
    }
    
    func frame(height: Binding<CGFloat>) -> Self {
        Layout.sizeFill(self, width: nil, height: .equal(.binding(height)))
        return self
    }
    
    func frame(width: Binding<CGFloat>, height: Binding<CGFloat>) -> Self {
        Layout.sizeFill(self, width: .equal(.binding(width)), height: .equal(.binding(height)))
        return self
    }
    
    func alignment(_ edges: Alignment, value: CGFloat? = 0) -> Self {
        var align = [Edge: CGFloat]()
        if edges.contains(.centerY) {
            align[.centerY] = value
        }
        if edges.contains(.centerX) {
            align[.centerX] = value
        }
        if edges.contains(.leading) {
            align[.leading] = value
        }
        if edges.contains(.trailing) {
            align[.trailing] = value
        }
        if edges.contains(.top) {
            align[.top] = value
        }
        if edges.contains(.bottom) {
            align[.bottom] = value
        }
        if edges.isEmpty {
            return self
        }
        Attribute.attribute(from: self).attrs.append(.alignment(align))
        return self
    }
    
    // 未完善
    //    func offset(x: CGFloat = 0, y: CGFloat = 0) -> UIView {
    //        let p = CGPoint(x: x, y: y)
    //        if p == .zero {
    //            return self
    //        }
    //
    //        return PaddingContainerView(self, offset: p)
    //    }
    
    /// padding将封装一个containerview，返回普通UIView类型
    func padding(top: CGFloat? = nil, leading: CGFloat? = nil, bottom: CGFloat? = nil, trailing: CGFloat? = nil) -> UIView {
        var mar = [Edge: CGFloat]()
        mar[.top] = top
        mar[.leading] = leading
        mar[.bottom] = bottom
        mar[.trailing] = trailing
        // 全空、全0
        if mar.isEmpty || mar.reduce(0, { partialResult, item in
            return partialResult + item.value
        }) == 0 {
            return self
        }
        return PaddingContainerView(self, padding: mar)
    }
    
    /// padding将封装一个containerview，返回普通UIView类型
    func padding(_ pad: CGFloat) -> UIView {
        return padding(top: pad, leading: pad, bottom: pad, trailing: pad)
    }
    
    /// padding将封装一个containerview，返回普通UIView类型
    func padding(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> UIView {
        return padding(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
}

internal struct Layout {
    static func alignSubview(_ view: UIView, subview: UIView, alignment: [Edge: CGFloat]) {
        // 对齐
        if let const = alignment[.centerY] {
            subview.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: const).isActive = true
        }
        if let const = alignment[.centerX] {
            subview.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: const).isActive = true
        }
        if let const = alignment[.leading] {
            subview.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: const).isActive = true
        }
        if let const = alignment[.trailing] {
            subview.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: const).isActive = true
        }
        if let const = alignment[.top] {
            subview.topAnchor.constraint(equalTo: view.topAnchor, constant: const).isActive = true
        }
        if let const = alignment[.bottom] {
            subview.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: const).isActive = true
        }
    }
    
    static func sizeFill(_ view: UIView, width: SizeFill?, height: SizeFill?) {
        private_sizeFill(view, width: width, height: height)
    }
    
    private static func private_sizeFill(_ view: UIView, width: SizeFill?, height: SizeFill?) {
        
        func dimensionAnchor(view: UIView, di: SizeFill.Dimension) -> NSLayoutDimension {
            switch di {
            case .x:
                return view.widthAnchor
            case .y:
                return view.heightAnchor
            }
        }
        
        func fillDimension(view: UIView, di: SizeFill.Dimension, sizefill: SizeFill) {
            switch sizefill {
            case .unknown:
                break
            case .equal(let valueBind):
                switch valueBind {
                case .constant(let value):
                    dimensionAnchor(view: view, di: di).constraint(equalToConstant: value).isActive = true
                case .binding(let bind):
                    let constraint = dimensionAnchor(view: view, di: di).constraint(equalToConstant: 0)
                    constraint.isActive = true
                    bind.addObserver(target: view) { [weak constraint] change in
                        constraint?.constant = change.new
                    }
                }
            }
        }
        
        if let si = width {
            fillDimension(view: view, di: .x, sizefill: si)
        }
        if let si = height {
            fillDimension(view: view, di: .y, sizefill: si)
        }
    }
}

public extension UIView {
    
    @discardableResult func arrangeViews(@ViewBuilder _ content: ViewBuilder.ContentBlock) -> Self {
        let views = content()
        var allActionsOnAppear = [() -> Void]()
        
        for view in views {
            let attribute = Attribute.attribute(from: view)
            var alignment: [Edge: CGFloat] = [:]
            for i in attribute.attrs {
                switch i {
                case .alignment(let ali):
                    for (k, v) in ali {
                        alignment[k] = v
                    }
                case .onAppear(let block):
                    allActionsOnAppear.append {
                        block?(view)
                    }
                }
            }
            let container = view // Layout.containerPaddingIfNeed(view, padding: padding, offset: offset)
            container.translatesAutoresizingMaskIntoConstraints = false
            if let stack = self as? UIStackView {
                stack.addArrangedSubview(container)
                // 针对stackview作为superview的IfBlock、ForEach等FakeInternalContainer
                if let fakeContainer = container as? FakeInternalContainer {
                    fakeContainer.didAddToSuperStackView(stack)
                }
            } else {
                addSubview(container)
                if alignment.isEmpty {
                    // 默认
                    alignment = [.top: 0, .leading: 0, .trailing: 0, .bottom: 0]
                }
                Layout.alignSubview(self, subview: container, alignment: alignment)
            }
        }
        
        for action in allActionsOnAppear {
            action()
        }
        
        return self
    }
}
