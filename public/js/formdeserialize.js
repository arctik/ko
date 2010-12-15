;(function($){
	$.fn.serializeObject = function(){
		var o = {};
		var a = this.serializeArray();
		for (i = 0; i < a.length; i += 1) {
			o = parseNestedParam(o, a[i].name, a[i].value);
		}
		return o;
	};
	function parseValue(value) {
		value = unescape(value);
		if (value === "true") {
			return true;
		} else if (value === "false") {
			return false;
		} else {
			return value;
		}
	};
	function parseNestedParam(params, field_name, field_value) {
		var match, name, rest;

		if (field_name.match(/^[^\[]+$/)) {
			// basic value
			params[field_name] = parseValue(field_value);
		} else if (match = field_name.match(/^([^\[]+)\[\](.*)$/)) {
			// array
			name = match[1];
			rest = match[2];

			if(params[name] && !$.isArray(params[name])) { throw('400 Bad Request'); }

			if (rest) {
				// array is not at the end of the parameter string
				match = rest.match(/^\[([^\]]+)\](.*)$/);
				if(!match) { throw('400 Bad Request'); }

				if (params[name]) {
					if(params[name][params[name].length - 1][match[1]]) {
						params[name].push(parseNestedParam({}, match[1] + match[2], field_value));
					} else {
						$.extend(true, params[name][params[name].length - 1], parseNestedParam({}, match[1] + match[2], field_value));
					}
				} else {
					params[name] = [parseNestedParam({}, match[1] + match[2], field_value)];
				}
			} else {
				// array is at the end of the parameter string
				if (params[name]) {
					params[name].push(parseValue(field_value));
				} else {
					params[name] = [parseValue(field_value)];
				}
			}
		} else if (match = field_name.match(/^([^\[]+)\[([^\[]+)\](.*)$/)) {
			// hash
			name = match[1];
			rest = match[2] + match[3];

			if (params[name] && $.isArray(params[name])) { throw('400 Bad Request'); }

			if (params[name]) {
				$.extend(true, params[name], parseNestedParam(params[name], rest, field_value));
			} else {
				params[name] = parseNestedParam({}, rest, field_value);
			}
		}
		return params;
	};
})(jQuery);
