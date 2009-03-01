$(document).ready(function(){
	if ($('input#user_videotron').val()=='VL') {
		$('input#user_videotron').css({'color':'#888'});
	};
	$('input#user_videotron').focus(function(){
		// si on a rien entre :
		if ($(this).val()=='VL') {
			$(this).val('');
		}
		// mettre la couleur noire
		$(this).css({'color':'#111'});
	}).blur(function(){
		// si ono a rien entre :
		if (!$(this).val()) {
			$(this).val('VL');
			// remettre la couleur gris
			$(this).css({'color':'#888'});
		};
	})
});
