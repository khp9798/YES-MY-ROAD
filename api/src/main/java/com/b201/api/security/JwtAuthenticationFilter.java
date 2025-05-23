package com.b201.api.security;

import java.io.IOException;
import java.util.Collections;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

	private final JwtUtil jwtUtil;
	private final StringRedisTemplate stringRedisTemplate;
	private final CustomUserDetailsService customUserDetailsService;

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
		FilterChain filterChain) throws ServletException, IOException {

		String uri = request.getRequestURI();
		log.debug("[JwtFilter] 요청 URI: {}", uri);

		// 회원가입, 로그인 등은 JWT 인증 없이 허용
		if (uri.startsWith("/api/users") || uri.startsWith("/api/detect")) {
			log.trace("[JwtFilter] 인증 스킵 URI: {}", uri);
			filterChain.doFilter(request, response);
			return;
		}

		// Authorization 헤더 추출
		String authHeader = request.getHeader("Authorization");
		log.debug("[JwtFilter] Authorization 헤더: {}", authHeader);

		// 헤더가 없거나 Bearer로 시작하지 않으면 다음 필터로 넘김
		if (authHeader == null || !authHeader.startsWith("Bearer ")) {
			log.warn("[JwtFilter] Authorization header가 비어있거나 형식이 잘못됨");
			response.setCharacterEncoding("UTF-8");
			response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
			response.getWriter().write("Authorization header가 비어있거나 유효하지 않습니다.");
			return;
		}

		String token = authHeader.substring(7); // "Bearer " 이후 실제 토큰 값
		log.debug("[JwtFilter] 추출된 토큰: {}", token);

		if (stringRedisTemplate.hasKey("BL:" + token)) {
			log.warn("[JwtFilter] 블랙리스트된 토큰 사용 시도: {}", token);
			response.setCharacterEncoding("UTF-8");
			response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
			response.getWriter().write("로그아웃된 토큰입니다.");
			return;
		}

		try {
			// 추출한 토큰 값을 검증해서 해당 user의 id를 추출
			String username = jwtUtil.getUsernameFromToken(token);
			log.debug("[JwtFilter] 토큰 유효, 사용자: {}", username);

			// username이 존재하고 현재 인증되지 않은 경우
			if (username != null && SecurityContextHolder.getContext().getAuthentication() == null) {
				UserDetails userDetails = customUserDetailsService.loadUserByUsername(username);
				
				// 사용자 인증 객체 생성
				UsernamePasswordAuthenticationToken authentication =
					new UsernamePasswordAuthenticationToken(userDetails, null, Collections.emptyList());

				// 현재 요청 정보를 사용자 인증 객체에 포함시킴 (IP, 세션 ID 등)
				authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

				// SecurityContext에 인증 객체 등록
				SecurityContextHolder.getContext().setAuthentication(authentication);

				log.debug("[JwtFilter] SecurityContext에 인증 객체 저장, 사용자: {}", username);
			}

		} catch (Exception e) {
			// jwt가 유효하지 않거나 존재하지 않는 경우 401 반환
			response.setCharacterEncoding("UTF-8");
			response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
			response.getWriter().write("JWT 토큰이 유효하지 않거나 만료되었습니다.");
			return;
		}

		// 다음 필터로 요청 전달
		filterChain.doFilter(request, response);
	}
}
