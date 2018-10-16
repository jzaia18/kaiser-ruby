module KaiserRuby
  class Parser
    attr_reader :lines, :raw_input, :tree

    POETIC_STRING_KEYWORDS = %w(says)
    POETIC_NUMBER_KEYWORDS = %w(is was were are 's 're)
    POETIC_NUMBER_CONTRACTIONS = %w('s 're)
    POETIC_TYPE_KEYWORDS = %w(is)
    PRINT_KEYWORDS = %w(say whisper shout scream)
    LISTEN_KEYWORDS = ['listen to']
    BREAK_KEYWORDS = ['break', 'break it down']
    CONTINUE_KEYWORDS = ['continue', 'take it to the top']
    RETURN_KEYWORDS = ['give back']

    INCREMENT_FIRST_KEYWORDS = %w(build)
    INCREMENT_SECOND_KEYWORDS = %w(up)
    DECREMENT_FIRST_KEYWORDS = %w(knock)
    DECREMENT_SECOND_KEYWORDS = %w(down)
    ASSIGNMENT_FIRST_KEYWORDS = %w(put)
    ASSIGNMENT_SECOND_KEYWORDS = %w(into)

    FUNCTION_KEYWORDS = %w(takes)
    FUNCTION_SEPARATORS = ['and', ', and', "'n'", '&', ',']
    FUNCTION_CALL_KEYWORDS = %w(taking)
    FUNCTION_CALL_SEPARATORS = [', and', "'n'", '&', ',']
    IF_KEYWORDS = %w(if)
    UNTIL_KEYWORDS = %w(until)
    WHILE_KEYWORDS = %w(while)
    ELSE_KEYWORDS = %w(else)

    NULL_TYPE = %w(null nothing nowhere nobody gone empty)
    TRUE_TYPE = %w(true yes ok right)
    FALSE_TYPE = %w(false no lies wrong)
    NIL_TYPE = %w(mysterious)
    POETIC_TYPE_LITERALS = NIL_TYPE + NULL_TYPE + TRUE_TYPE + FALSE_TYPE

    COMMON_VARIABLE_KEYWORDS = %w(a an the my your)
    PRONOUN_KEYWORDS = %w(he him she her it its they them)

    ADDITION_KEYWORDS = %w(plus with)
    SUBTRACTION_KEYWORDS = %w(minus without)
    MULTIPLICATION_KEYWORDS = %w(times of)
    DIVISION_KEYWORDS = %w(over)
    MATH_OP_KEYWORDS = ADDITION_KEYWORDS + SUBTRACTION_KEYWORDS + MULTIPLICATION_KEYWORDS + DIVISION_KEYWORDS

    EQUALITY_KEYWORDS = %w(is)
    INEQUALITY_KEYWORDS = %w(isn't isnt ain't aint)
    GT_KEYWORDS = ['is higher than', 'is greater than', 'is bigger than', 'is stronger than']
    GTE_KEYWORDS = ['is as high as', 'is as great as', 'is as big as', 'is as strong as']
    LT_KEYWORDS = ['is lower than', 'is less than', 'is smaller than', 'is weaker than']
    LTE_KEYWORDS = ['is as low as', 'is as little as', 'is as small as', 'is as weak as']
    COMPARISON_KEYWORDS = EQUALITY_KEYWORDS + INEQUALITY_KEYWORDS + GT_KEYWORDS + GTE_KEYWORDS + LT_KEYWORDS + LTE_KEYWORDS

    FUNCTION_RESTRICTED_KEYWORDS = MATH_OP_KEYWORDS + ['(?<!, )and', 'is', 'or', 'into']

    AND_KEYWORDS = %w(and)
    OR_KEYWORDS = %w(or)
    NOR_KEYWORDS = %w(nor)
    LOGIC_KEYWORDS = %w(and or nor)

    RESERVED_KEYWORDS = LOGIC_KEYWORDS + MATH_OP_KEYWORDS + POETIC_TYPE_LITERALS

    def initialize(input)
      @raw_input = input
      @lines = input.split /\n/
    end

    def parse
      @tree = []

      @tree.extend(Hashie::Extensions::DeepLocate)
      @function_temp = []
      @nesting = 0

      # parse through lines to get the general structure (statements/flow control/functions/etc) out of it
      @lines.each do |line|
        parse_line(line)
      end

      func_calls = @tree.deep_locate(:passed_function_call)
      func_calls.each do |func|
        str = func[:passed_function_call]
        num = Integer(str.split('_').last)

        func[:passed_function_call] = parse_function_call(@function_temp[num])
      end

      @tree
    end

    def parse_line(line)
      if line.strip.empty?
        @nesting -= 1 if @nesting > 0
        add_to_tree(parse_empty_line)
      else
        words = line.split /\s/

        if matches_first?(words, IF_KEYWORDS)
          add_to_tree parse_if(line)
          @nesting += 1
        elsif matches_first?(words, ELSE_KEYWORDS)
          add_to_tree parse_else
        elsif matches_first?(words, WHILE_KEYWORDS)
          add_to_tree parse_while(line)
          @nesting += 1
        elsif matches_first?(words, UNTIL_KEYWORDS)
          add_to_tree parse_until(line)
          @nesting += 1
        elsif matches_separate?(words, ASSIGNMENT_FIRST_KEYWORDS, ASSIGNMENT_SECOND_KEYWORDS)
          add_to_tree parse_assignment(line)
        elsif matches_several_first?(line, RETURN_KEYWORDS)
          add_to_tree parse_return(line)
        elsif matches_first?(words, PRINT_KEYWORDS)
          add_to_tree parse_print(line)
        else
          if matches_any?(words, POETIC_STRING_KEYWORDS)
            add_to_tree parse_poetic_string(line)
          elsif matches_any?(words, POETIC_NUMBER_KEYWORDS)
            add_to_tree parse_poetic_type_all(line)
          else
            add_to_tree(parse_listen(line)) if matches_several_first?(line, LISTEN_KEYWORDS)
            add_to_tree(parse_break) if matches_several_first?(line, BREAK_KEYWORDS)
            add_to_tree(parse_continue) if matches_several_first?(line, CONTINUE_KEYWORDS)
            add_to_tree(parse_function_call(line)) if matches_any?(words, FUNCTION_CALL_KEYWORDS)

            if matches_separate?(words, INCREMENT_FIRST_KEYWORDS, INCREMENT_SECOND_KEYWORDS)
              add_to_tree parse_increment(line)
            end

            if matches_separate?(words, DECREMENT_FIRST_KEYWORDS, DECREMENT_SECOND_KEYWORDS)
              add_to_tree parse_decrement(line)
            end

            if matches_any?(words, FUNCTION_KEYWORDS)
              add_to_tree(parse_function(line))
              @nesting += 1
            end
          end
        end
      end
    end

    # statements
    def parse_print(line)
      words = line.split prepared_regexp(PRINT_KEYWORDS)
      arg = consume_function_calls(words.last.strip)
      argument = parse_argument(arg)

      { print: argument }
    end

    def parse_listen(line)
      words = line.split prepared_regexp(LISTEN_KEYWORDS)

      { listen: parse_variables(words.last.strip) }
    end

    def parse_return(line)
      words = line.split prepared_regexp(RETURN_KEYWORDS)
      arg = consume_function_calls(words.last.strip)
      argument = parse_argument(arg)
      { return: argument }
    end

    def parse_increment(line)
      match_rxp = prepared_capture(INCREMENT_FIRST_KEYWORDS, INCREMENT_SECOND_KEYWORDS)
      capture = parse_variables(line.match(match_rxp).captures.first.strip)

      { increment: capture }
    end

    def parse_decrement(line)
      match_rxp = prepared_capture(DECREMENT_FIRST_KEYWORDS, DECREMENT_SECOND_KEYWORDS)
      capture = parse_variables(line.match(match_rxp).captures.first.strip)

      { decrement: capture }
    end

    def parse_else
      { else: nil }
    end

    def parse_empty_line
      { empty_line: nil }
    end

    def parse_break
      { break: nil }
    end

    def parse_continue
      { continue: nil }
    end

    def parse_function_definition_arguments(string)
      words = string.split Regexp.new(FUNCTION_SEPARATORS.join('|'))
      arguments = []
      words.each do |w|
        arg = parse_value_or_variable(w.strip)
        arg[:local_variable_name] = arg.delete(:variable_name)
        arguments << arg
      end

      { argument_list: arguments }
    end

    def parse_function_call_arguments(string)
      words = string.split(Regexp.new(FUNCTION_CALL_SEPARATORS.join('|')))
      arguments = []
      words.each do |w|
        arguments << parse_value_or_variable(w.strip)
      end

      { argument_list: arguments }
    end

    def parse_function_call(line)
      words = line.split /\s/
      if matches_any?(words, FUNCTION_CALL_KEYWORDS)
        words = line.split prepared_regexp(FUNCTION_CALL_KEYWORDS)
        left = parse_function_name(words.first.strip)
        right = parse_function_call_arguments(words.last.strip)
        { function_call: { left: left, right: right } }
      else
        return false
      end
    end

    def parse_poetic_string(line)
      words = line.partition prepared_regexp(POETIC_STRING_KEYWORDS)
      left = parse_variables(words.first.strip)
      right = { string: "\"#{words.last.strip}\"" }
      { poetic_string: { left: left, right: right } }
    end

    def parse_poetic_type_all(line)
      words = line.partition prepared_regexp(POETIC_NUMBER_KEYWORDS)
      left = parse_variables(words.first.strip)
      right = parse_type_value(words.last.strip)
      { poetic_type: { left: left, right: right } }
    end

    def parse_type_value(string)
      words = string.split /\s/

      if matches_first?(words, NIL_TYPE)
        { type: 'nil' }
      elsif matches_first?(words, NULL_TYPE)
        { type: 'null' }
      elsif matches_first?(words, TRUE_TYPE)
        { type: 'true' }
      elsif matches_first?(words, FALSE_TYPE)
        { type: 'false' }
      elsif string.strip.start_with?('"') && string.strip.end_with?('"')
        parse_literal_string(string)
      else
        parse_poetic_number_value(string)
      end
    end

    def parse_type_literal(string)
      words = string.split /\s/
      raise SyntaxError, "too many words in poetic type literal: #{string}" if words.size > 1

      if matches_first?(words, NIL_TYPE)
        { type: 'nil' }
      elsif matches_first?(words, NULL_TYPE)
        { type: 'null' }
      elsif matches_first?(words, TRUE_TYPE)
        { type: 'true' }
      elsif matches_first?(words, FALSE_TYPE)
        { type: 'false' }
      else
        raise SyntaxError, "unknown poetic type literal: #{string}"
      end
    end

    def parse_assignment(line)
      match_rxp = prepared_capture(ASSIGNMENT_FIRST_KEYWORDS, ASSIGNMENT_SECOND_KEYWORDS)
      right = parse_argument(line.match(match_rxp).captures.first.strip)
      left = parse_variables(line.match(match_rxp).captures.last.strip)

      { assignment: { left: left, right: right } }
    end

    def parse_if(line)
      words = line.split prepared_regexp(IF_KEYWORDS)

      arg = consume_function_calls(words.last.strip)
      argument = parse_argument(arg)
      { if: { argument: argument } }
    end

    def parse_until(line)
      words = line.split prepared_regexp(UNTIL_KEYWORDS)
      arg = consume_function_calls(words.last.strip)
      argument = parse_argument(arg)
      { until: { argument: argument } }
    end

    def parse_while(line)
      words = line.split prepared_regexp(WHILE_KEYWORDS)
      arg = consume_function_calls(words.last.strip)
      argument = parse_argument(arg)
      { while: { argument: argument } }
    end

    def parse_function(line)
      words = line.split prepared_regexp(FUNCTION_KEYWORDS)
      funcname = parse_function_name(words.first.strip)
      argument = parse_function_definition_arguments(words.last.strip)
      { function: { name: funcname, argument: argument } }
    end

    def consume_function_calls(string)
      if string =~ prepared_regexp(FUNCTION_CALL_KEYWORDS)
        words = string.split prepared_regexp(FUNCTION_RESTRICTED_KEYWORDS)
        found_string = words.select { |w| w =~ (/\btaking\b/) }.first
        @function_temp << found_string
        string = string.gsub(found_string, " func_#{@function_temp.count - 1} ")
      end

      string
    end

    def pass_function_calls(string)
      if string.strip =~ /func_\d+\Z/
        { passed_function_call: string }
      else
        return false
      end
    end

    def parse_argument(string)
      str = parse_literal_string(string)
      return str if str

      exp = parse_logic_operation(string)
      return exp if exp

      cmp = parse_comparison(string)
      return cmp if cmp

      math = parse_math_operations(string)
      return math if math

      fcl2 = pass_function_calls(string)
      return fcl2 if fcl2

      fcl = parse_function_call(string)
      return fcl if fcl

      vals = parse_value_or_variable(string)
      return vals if vals
    end

    def parse_value_or_variable(string)
      str = parse_literal_string(string)
      return str if str

      num = parse_literal_number(string)
      return num if num

      vars = parse_variables(string)
      return vars if vars

      tpl = parse_type_literal(string)
      return tpl if tpl
    end

    def parse_poetic_number_value(string)
      num = parse_literal_number(string)
      if num
        return num
      else
        return { number_literal: string.strip }
      end
    end

    def parse_logic_operation(string)
      testable = string.partition(prepared_regexp(LOGIC_KEYWORDS))
      return false if testable.first.count('"').odd? || testable.last.count('"').odd?

      if string =~ prepared_regexp(AND_KEYWORDS)
        return parse_and(string)
      elsif string =~ prepared_regexp(OR_KEYWORDS)
        return parse_or(string)
      elsif string =~ prepared_regexp(NOR_KEYWORDS)
        # TODO
      end

      return false
    end

    def parse_and(string)
      words = string.rpartition prepared_regexp(AND_KEYWORDS)
      left = parse_argument(words.first.strip)
      right = parse_argument(words.last.strip)

      { and: { left: left, right: right } }
    end

    def parse_or(string)
      words = string.rpartition prepared_regexp(OR_KEYWORDS)

      left = parse_argument(words.first.strip)
      right = parse_argument(words.last.strip)

      { or: { left: left, right: right } }
    end

    def parse_comparison(string)
      return false if string.strip.start_with?('"') && string.strip.strip.end_with?('"') && string.count('"') == 2
      words = string.split(/\s/)

      if string =~ prepared_regexp(GT_KEYWORDS)
        return parse_gt(string)
      elsif string =~ prepared_regexp(GTE_KEYWORDS)
        return parse_gte(string)
      elsif string =~ prepared_regexp(LT_KEYWORDS)
        return parse_lt(string)
      elsif string =~ prepared_regexp(LTE_KEYWORDS)
        return parse_lte(string)
      elsif string =~ prepared_regexp(INEQUALITY_KEYWORDS)
        return parse_inequality(string)
      elsif string =~ prepared_regexp(EQUALITY_KEYWORDS)
        return parse_equality(string)
      end

      return false
    end

    def parse_equality(string)
      words = string.rpartition prepared_regexp(EQUALITY_KEYWORDS)
      left = parse_argument(words.first.strip)
      right = parse_argument(words.last.strip)

      { equality: { left: left, right: right } }
    end

    def parse_inequality(string)
      words = string.rpartition prepared_regexp(INEQUALITY_KEYWORDS)
      left = parse_argument(words.first.strip)
      right = parse_argument(words.last.strip)

      { inequality: { left: left, right: right } }
    end

    def parse_gt(string)
      words = string.rpartition prepared_regexp(GT_KEYWORDS)
      left = parse_argument(words.first.strip)
      right = parse_argument(words.last.strip)

      { gt: { left: left, right: right } }
    end

    def parse_gte(string)
      words = string.rpartition prepared_regexp(GTE_KEYWORDS)
      left = parse_argument(words.first.strip)
      right = parse_argument(words.last.strip)

      { gte: { left: left, right: right } }
    end

    def parse_lt(string)
      words = string.rpartition prepared_regexp(LT_KEYWORDS)
      left = parse_argument(words.first.strip)
      right = parse_argument(words.last.strip)

      { lt: { left: left, right: right } }
    end

    def parse_lte(string)
      words = string.rpartition prepared_regexp(LTE_KEYWORDS)
      left = parse_argument(words.first.strip)
      right = parse_argument(words.last.strip)

      { lte: { left: left, right: right } }
    end

    def parse_variables(string)
      words = string.split /\s/
      words = words.map { |e| e.chars.select { |c| c =~ /[[:alnum:]]|\./ }.join }
      string = words.join(' ')

      if string =~ prepared_regexp(PRONOUN_KEYWORDS)
        return parse_pronoun
      elsif matches_first?(words, COMMON_VARIABLE_KEYWORDS)
        return parse_common_variable(string)
      elsif matches_all?(words, /\A[[:upper:]]/) && string !~ prepared_regexp(RESERVED_KEYWORDS)
        return parse_proper_variable(string)
      end

      return false
    end

    def parse_function_name(string)
      fname = parse_variables(string)
      fname[:function_name] = fname.delete(:variable_name)
      fname
    end

    def parse_common_variable(string)
      words = string.split(/\s/)

      copied = words.dup
      copied.shift
      copied.each do |w|
        raise SyntaxError, "invalid common variable name: #{string}" if w =~ /[[:upper:]]/
      end

      words = words.map { |e| e.chars.select { |c| c =~ /[[:alpha:]]/ }.join }
      { variable_name: words.map { |w| w.downcase }.join('_') }
    end

    def parse_proper_variable(string)
      words = string.split(/\s/)

      copied = words.dup
      copied.shift
      copied.each do |w|
        raise SyntaxError, "invalid proper variable name: #{string}" unless w =~ /\A[[:upper:]]/
      end

      words = words.map { |e| e.chars.select { |c| c =~ /[[:alpha:]]/ }.join }
      { variable_name: words.map { |w| w.downcase }.join('_') }
    end

    def parse_pronoun
      { pronoun: nil }
    end

    def parse_math_operations(string)
      return false if string.strip.start_with?('"') && string.strip.end_with?('"') && string.count('"') == 2
      words = string.split(/\s/)

      if matches_any?(words, MULTIPLICATION_KEYWORDS)
        return parse_multiplication(string)
      elsif matches_any?(words, DIVISION_KEYWORDS)
        return parse_division(string)
      elsif matches_any?(words, ADDITION_KEYWORDS)
        return parse_addition(string)
      elsif matches_any?(words, SUBTRACTION_KEYWORDS)
        return parse_subtraction(string)
      end

      return false
    end

    def parse_addition(string)
      words = string.rpartition prepared_regexp(ADDITION_KEYWORDS)
      left = parse_argument(words.first.strip)
      right = parse_argument(words.last.strip)

      { addition: { left: left, right: right } }
    end

    def parse_subtraction(string)
      words = string.rpartition prepared_regexp(SUBTRACTION_KEYWORDS)
      left = parse_argument(words.first.strip)
      right = parse_argument(words.last.strip)

      { subtraction: { left: left, right: right } }
    end

    def parse_multiplication(string)
      words = string.rpartition prepared_regexp(MULTIPLICATION_KEYWORDS)
      left = parse_argument(words.first.strip)
      right = parse_argument(words.last.strip)

      { multiplication: { left: left, right: right } }
    end

    def parse_division(string)
      words = string.rpartition prepared_regexp(DIVISION_KEYWORDS)
      left = parse_argument(words.first.strip)
      right = parse_argument(words.last.strip)

      { division: { left: left, right: right } }
    end

    def parse_literal_string(string)
      if string.strip.start_with?('"') && string.strip.end_with?('"') && string.count('"') == 2
        { string: string }
      else
        return false
      end
    end

    def parse_literal_number(string)
      num = Float(string) rescue string
      if num.is_a?(Float)
        { number: num }
      else
        return false
      end
    end

    #private

    def add_to_tree(object)
      object.extend(Hashie::Extensions::DeepLocate)

      object[:nesting] = @nesting if @nesting > 0
      @tree << object
    end

    def prepared_regexp(array)
      rxp = array.map { |a| '\b' + a + '\b' }.join('|')
      Regexp.new(rxp, Regexp::IGNORECASE)
    end

    def prepared_capture(farr, sarr)
      frxp = farr.map { |a| '\b' + a + '\b' }.join('|')
      srxp = sarr.map { |a| '\b' + a + '\b' }.join('|')
      Regexp.new(frxp + '(.*?)' + srxp + '(.*)', Regexp::IGNORECASE)
    end

    def matches_any?(words, rxp)
      regexp = rxp.is_a?(Regexp) ? rxp : prepared_regexp(rxp)
      words.any? { |w| w =~ regexp }
    end

    def matches_all?(words, rxp)
      regexp = rxp.is_a?(Regexp) ? rxp : prepared_regexp(rxp)
      words.all? { |w| w =~ regexp }
    end

    def matches_consecutive?(words, first_rxp, second_rxp)
      first_idx = words.index { |w| w =~ prepared_regexp(first_rxp) }
      second_idx = words.index { |w| w =~ prepared_regexp(second_rxp) }

      second_idx != nil && first_idx != nil && second_idx.to_i - first_idx.to_i == 1
    end

    def matches_first?(words, rxp)
      words.index { |w| w =~ prepared_regexp(rxp) } == 0
    end

    def matches_several_first?(line, rxp)
      (line =~ prepared_regexp(rxp)) == 0
    end

    def matches_separate?(words, first_rxp, second_rxp)
      first_idx = words.index { |w| w =~ prepared_regexp(first_rxp) }
      second_idx = words.index { |w| w =~ prepared_regexp(second_rxp) }

      second_idx != nil && first_idx != nil && second_idx.to_i > first_idx.to_i
    end
  end
end