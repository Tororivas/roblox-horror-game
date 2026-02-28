--!strict
-- Global type definitions for Roblox APIs

export type Vector2 = {
    X: number,
    Y: number,
    x: number,
    y: number,
    Magnitude: number,
    Unit: Vector2,
}

export type Vector3 = {
    X: number,
    Y: number,
    Z: number,
    x: number,
    y: number,
    z: number,
    Magnitude: number,
    Unit: Vector3,
}

export type Color3 = {
    R: number,
    G: number,
    B: number,
    r: number,
    g: number,
    b: number,
}

export type Instance = {
    Name: string,
    ClassName: string,
    Parent: Instance?,
}

export type BasePart = Instance & {
    Position: Vector3,
    CFrame: CFrame,
    Size: Vector3,
    Anchored: boolean,
    CanCollide: boolean,
    Color: Color3,
}

export type Model = Instance & {
    PrimaryPart: BasePart?,
}

export type Player = Instance & {
    UserId: number,
    Character: Model?,
}

export type CFrame = {
    Position: Vector3,
    LookVector: Vector3,
}

export type Team = Instance & {}

export type BrickColor = {
    Name: string,
    Color: Color3,
}

type EnumItem = {
    Name: string,
    Value: number,
}
