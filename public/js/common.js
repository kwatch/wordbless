function inspect(obj) {
	var buf = [];
	for (var p in obj) {
		buf.push(p+'="'+obj[p]+'"');
	}
	return buj.join(', ');
}