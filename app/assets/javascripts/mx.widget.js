!(function() {
	
	var mx = this.mx || (this.mx = {}); mx.widget || (mx.widget = {});

	function query(element) {
		return isNode(element) ? element : document.getElementById(element);
	}

	function isNode(el) {
		return (el && el.nodeType && (el.nodeType == 1 || el.nodeType == 9));
	}
	

	// entry point
	
	mx.widget.table = function(element, options) {
		query(element).innerHTML = '<iframe src="http://widgets.dev/widget" scrolling="no" frameborder="0" style="border:none; overflow:hidden;" allowTransparency="true"></iframe>';
	}
	
})();
