module Natalie
  class Compiler
    INSTRUCTIONS = [
      AliasGlobalInstruction,
      AliasMethodInstruction,
      ArrayConcatInstruction,
      ArrayPopInstruction,
      ArrayPopWithDefaultInstruction,
      ArrayPushInstruction,
      ArrayShiftInstruction,
      ArrayShiftWithDefaultInstruction,
      ArrayWrapInstruction,
      AutoloadConstInstruction,
      BreakInstruction,
      BreakOutInstruction,
      CaseEqualInstruction,
      CatchInstruction,
      CheckArgsInstruction,
      CheckExtraKeywordsInstruction,
      CheckRequiredKeywordsInstruction,
      ClassVariableGetInstruction,
      ClassVariableSetInstruction,
      ConstFindInstruction,
      ConstSetInstruction,
      ContinueInstruction,
      CreateArrayInstruction,
      CreateComplexInstruction,
      CreateHashInstruction,
      CreateLambdaInstruction,
      CreateRangeInstruction,
      DefineBlockInstruction,
      DefineClassInstruction,
      DefineMethodInstruction,
      DefineModuleInstruction,
      DupInstruction,
      DupObjectInstruction,
      DupRelInstruction,
      ElseInstruction,
      EndInstruction,
      GlobalVariableDefinedInstruction,
      GlobalVariableGetInstruction,
      GlobalVariableSetInstruction,
      HashDeleteInstruction,
      HashDeleteWithDefaultInstruction,
      HashMergeInstruction,
      HashPutInstruction,
      IfInstruction,
      InlineCppInstruction,
      InstanceVariableDefinedInstruction,
      InstanceVariableGetInstruction,
      InstanceVariableSetInstruction,
      IsDefinedInstruction,
      IsNilInstruction,
      LoadFileInstruction,
      MatchBreakPointInstruction,
      MatchExceptionInstruction,
      MethodDefinedInstruction,
      MoveRelInstruction,
      NextInstruction,
      NotInstruction,
      PopInstruction,
      PopKeywordArgsInstruction,
      PushArgInstruction,
      PushArgcInstruction,
      PushArgsInstruction,
      PushBlockInstruction,
      PushFalseInstruction,
      PushFloatInstruction,
      PushIntInstruction,
      PushLastMatchInstruction,
      PushNilInstruction,
      PushObjectClassInstruction,
      PushRationalInstruction,
      PushRegexpInstruction,
      PushRescuedInstruction,
      PushSelfInstruction,
      PushStringInstruction,
      PushSymbolInstruction,
      PushTrueInstruction,
      RedoInstruction,
      RetryInstruction,
      ReturnInstruction,
      SendInstruction,
      ShellInstruction,
      SingletonClassInstruction,
      StringAppendInstruction,
      StringToRegexpInstruction,
      SuperInstruction,
      SwapInstruction,
      ToArrayInstruction,
      TryInstruction,
      UndefineMethodInstruction,
      VariableDeclareInstruction,
      VariableGetInstruction,
      VariableSetInstruction,
      WhileBodyInstruction,
      WhileInstruction,
      WithSingletonInstruction,
      YieldInstruction
    ].freeze
  end
end
